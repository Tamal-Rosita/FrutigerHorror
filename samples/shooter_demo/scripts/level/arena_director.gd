extends Node3D
class_name ArenaDirector

## Wave director for the jam arena: spawns mixed Windows/office enemies in
## rounds, tracks kills, shows banners, flashes red when the player is hit and
## auto-restarts the arena when the player dies.

const VRM_COLLEAGUE: PackedScene = preload("res://samples/shooter_demo/scenes/enemies/vrm_colleague_enemy.tscn")
const BSOD: PackedScene = preload("res://samples/shooter_demo/scenes/enemies/bsod_enemy.tscn")
const BLISS: PackedScene = preload("res://samples/shooter_demo/scenes/enemies/bliss_enemy.tscn")
const ERROR: PackedScene = preload("res://samples/shooter_demo/scenes/enemies/error_enemy.tscn")
const WOUNDED_ALLY: PackedScene = preload("res://samples/shooter_demo/scenes/wounded_ally.tscn")
const AMMO_PICKUP: PackedScene = preload("res://samples/shooter_demo/scenes/pickups/ammo_pickup.tscn")

const SPAWN_RADIUS_MIN := 26.0
const SPAWN_RADIUS_MAX := 34.0

@export var player_path: NodePath
## The arena is a level: this many rounds, then a win state.
@export var total_rounds: int = 3

var _player: Node3D
var _player_health: Node
var _round: int = 0
var _killed: int = 0
var _round_count: int = 0
var _running: bool = false
var finished: bool = false

var _banner: Label
var _wave_label: Label
var _flash: ColorRect
var _flash_tween: Tween


func _ready() -> void:
	_build_ui()
	_player = get_node_or_null(player_path) if not player_path.is_empty() else null
	if _player:
		_player_health = _player.get_node_or_null("Health")
		if _player_health:
			_player_health.died.connect(_on_player_died)
			_player_health.damaged.connect(_on_player_damaged)
	_spawn_ally()
	for pos in [Vector3(-6, 0.35, -8), Vector3(6, 0.35, 10), Vector3(-9, 0.35, 12)]:
		_spawn_ammo_pickup(pos)
	_replenish_pickups()
	_start_round(1)


## The wounded co-worker to defend: speaks when you get close, dies for real.
func _spawn_ally() -> void:
	var allies := Node3D.new()
	allies.name = "Allies"
	add_child(allies)
	var ally := WOUNDED_ALLY.instantiate()
	allies.add_child(ally)
	ally.global_position = Vector3(-6.0, 0.0, 4.0)
	ally.set("player_path", _player.get_path())
	var ally_health := ally.get_node("Health")
	ally_health.died.connect(_on_ally_died)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArenaUI"
	add_child(layer)

	_flash = ColorRect.new()
	_flash.name = "DamageFlash"
	_flash.color = Color(0.8, 0.05, 0.08, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash)

	_wave_label = Label.new()
	_wave_label.name = "WaveLabel"
	_wave_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_wave_label.offset_top = 14.0
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 30)
	_wave_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_wave_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_wave_label)

	_banner = Label.new()
	_banner.name = "Banner"
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_color", Color(0.75, 0.95, 1))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_banner.add_theme_constant_override("outline_size", 10)
	layer.add_child(_banner)


func _start_round(round: int) -> void:
	if finished:
		return
	_round = round
	_round_count = mini(2 + round * 2, 14)
	_killed = 0
	_running = true
	_show_banner("ROUND %d" % round, "ENEMIES ARE NOT PEOPLE\nSHE TOLD HERSELF", 2.0)
	_wave_label.text = "ROUND %d — %d targets" % [round, _round_count]
	_spawn_wave()


func _spawn_wave() -> void:
	for i in _round_count:
		if not _running:
			return
		_spawn_enemy()
		var gap: float = maxf(0.45, 1.0 - _round * 0.07)
		await get_tree().create_timer(gap).timeout
	# Wait for the floor to clear.
	while _running and _killed < _round_count:
		await get_tree().create_timer(0.25).timeout
	if not _running:
		return
	_wave_label.text = "FLOOR CLEAR"
	_show_banner("FLOOR CLEARED", "IT GETS WORSE WHEN YOU REMEMBER THEIR NAMES", 2.2)
	await get_tree().create_timer(2.6).timeout
	if _running:
		if _round >= total_rounds:
			_on_victory()
		else:
			_start_round(_round + 1)


func _spawn_enemy() -> void:
	var scene: PackedScene = _pick_enemy_scene()
	var enemy := scene.instantiate()
	$Enemies.add_child(enemy)
	var angle := randf() * TAU
	var radius := randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	enemy.global_position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	enemy.set("player_path", _player.get_path())
	enemy.downed.connect(_on_enemy_down)


func _spawn_ammo_pickup(pos: Vector3) -> void:
	var pick := AMMO_PICKUP.instantiate()
	$Pickups.add_child(pick)
	pick.global_position = pos


func _replenish_pickups() -> void:
	while is_inside_tree():
		await get_tree().create_timer(12.0).timeout
		if not _running:
			return
		if get_tree().get_nodes_in_group("AmmoPickups").size() < 4:
			var angle := randf() * TAU
			_spawn_ammo_pickup(Vector3(cos(angle) * randf_range(10.0, 22.0), 0.35, sin(angle) * randf_range(10.0, 22.0)))


func _pick_enemy_scene() -> PackedScene:
	var roll := randf()
	if roll < 0.45:
		return VRM_COLLEAGUE
	elif roll < 0.65:
		return BSOD
	elif roll < 0.83:
		return ERROR
	return BLISS


func _on_enemy_down(_target: Node) -> void:
	_killed += 1
	_wave_label.text = "ROUND %d — %d left" % [_round, _round_count - _killed]


func _on_player_damaged(_amount: int, _hit: Dictionary) -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = Color(0.8, 0.05, 0.08, 0.35)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.45)


func _on_victory() -> void:
	_running = false
	finished = true
	_wave_label.text = "LEVEL CLEARED — ESC for menu"
	_show_banner("THE DREAM ENDS", "you finally remembered to log off", 7.0)
	# Leave the arena running so the player can walk the cleared floor.
	get_tree().paused = false


func _on_player_died(_hit: Dictionary) -> void:
	if finished:
		return
	_running = false
	_show_banner("TERMINATED", "you were always the error message", 3.0)
	await get_tree().create_timer(2.8).timeout
	get_tree().reload_current_scene()


func _on_ally_died(_hit: Dictionary) -> void:
	if not _running or finished:
		return
	_running = false
	_show_banner("SHE DIDN'T WAKE UP", "some people stay logged in forever", 3.0)
	await get_tree().create_timer(2.8).timeout
	get_tree().reload_current_scene()


func _show_banner(title: String, subtitle: String, duration: float) -> void:
	_banner.text = title + "\n" + subtitle
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	tween.tween_interval(maxf(0.0, duration - 0.9))
	tween.tween_property(_banner, "modulate:a", 0.0, 0.55)
	tween.tween_callback(func() -> void: _banner.visible = false)
