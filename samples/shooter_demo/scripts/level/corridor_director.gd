extends Node3D
class_name CorridorDirector

## Office-corridor level runner: the player walks through rooms/doors and each
## ambush zone wakes a few VRM colleagues once entered. Only the colleague
## enemy is used here. Like the arena, combat waits until the player has
## talked to Celia (novel-engine prompt, press X).

const COLLEAGUE: PackedScene = preload("res://samples/shooter_demo/scenes/enemies/vrm_colleague_enemy.tscn")
const WOUNDED_ALLY: PackedScene = preload("res://samples/shooter_demo/scenes/wounded_ally.tscn")
const UI_THEME: Theme = preload("res://samples/shooter_demo/ui/shooter_theme.tres")

## How many colleagues wake in each zone (rooms along the corridor).
@export var zone_spawn_counts: Array[int] = [2, 3, 4, 4]
@export var player_path: NodePath

var _player: Node3D
var _intro_done: bool = false
var _zone_index: int = 0
var _zone_kills: int = 0
var _zone_alive: int = 0
var _finished: bool = false

var _banner: RichTextLabel
var _status: Label


func _ready() -> void:
	_build_ui()
	_player = get_node_or_null(player_path) if not player_path.is_empty() else null
	if _player:
		var health := _player.get_node_or_null("Health")
		if health:
			health.died.connect(_on_player_died)
	_spawn_ally()
	_connect_triggers()
	Dialogic.timeline_ended.connect(_on_intro_timeline_ended)
	_status.text = "HABLA CON CELIA (acércate y presiona X)"


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CorridorUI"
	add_child(layer)

	var root := Control.new()
	root.name = "UI"
	root.theme = UI_THEME
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	_status = Label.new()
	_status.name = "StatusLabel"
	_status.theme_type_variation = &"WaveStatus"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top = 14.0
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_status.add_theme_constant_override("outline_size", 6)
	root.add_child(_status)
	
	_banner = RichTextLabel.new()
	_banner.name = "Banner"
	_banner.theme_type_variation = &"BannerRich"
	_banner.bbcode_enabled = true
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.scroll_active = false
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -640.0
	_banner.offset_top = -170.0
	_banner.offset_right = 640.0
	_banner.offset_bottom = 190.0
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_banner.add_theme_constant_override("outline_size", 12)
	root.add_child(_banner)


func _spawn_ally() -> void:
	var allies := Node3D.new()
	allies.name = "Allies"
	add_child(allies)
	var ally := WOUNDED_ALLY.instantiate()
	allies.add_child(ally)
	ally.global_position = Vector3(-42.0, 0.0, 2.5)
	ally.set("player_path", _player.get_path())
	var health := ally.get_node("Health")
	health.died.connect(_on_ally_died)


func _connect_triggers() -> void:
	var holder := get_node_or_null("Triggers")
	if holder == null:
		return
	for child in holder.get_children():
		if child is Area3D:
			(child as Area3D).body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node3D) -> void:
	if not _intro_done or _finished:
		return
	if body != _player or _zone_alive > 0:
		return
	if _zone_index >= zone_spawn_counts.size():
		return
	_activate_zone()


func _activate_zone() -> void:
	var count: int = zone_spawn_counts[_zone_index]
	_zone_kills = 0
	_zone_alive = count
	var spawns := get_node_or_null("Spawns")
	var anchor: Node3D = null
	if spawns and _zone_index < spawns.get_child_count():
		anchor = spawns.get_child(_zone_index) as Node3D
	_status.text = "SALA %d/%d — %d colegas" % [_zone_index + 1, zone_spawn_counts.size(), count]
	for i in count:
		var enemy := COLLEAGUE.instantiate()
		$Enemies.add_child(enemy)
		var pos := (anchor.global_position if anchor else global_position) + Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-4.0, 4.0))
		enemy.global_position = pos
		enemy.set("player_path", _player.get_path())
		enemy.downed.connect(_on_enemy_down)
	_show_banner("SALA %d" % (_zone_index + 1), "estaban esperando en los pasillos", 1.6)
	_wait_for_zone_clear()


func _wait_for_zone_clear() -> void:
	while is_inside_tree() and _zone_alive > 0 and not _finished:
		await get_tree().create_timer(0.25).timeout
	if not is_inside_tree() or _finished:
		return
	_zone_index += 1
	if _zone_index >= zone_spawn_counts.size():
		_victory()
	else:
		_status.text = "PUERTAS ABIERTAS — SIGUE AVANZANDO (%d restantes)" % (zone_spawn_counts.size() - _zone_index)
		_show_banner("SALA DESPEJADA", "sigue avanzando entre las oficinas", 1.6)


func _on_enemy_down(_enemy: Node) -> void:
	_zone_kills += 1
	_zone_alive -= 1
	_status.text = "SALA %d/%d — %d restantes" % [_zone_index + 1, zone_spawn_counts.size(), maxi(_zone_alive, 0)]


func _on_intro_timeline_ended() -> void:
	if _intro_done or _finished:
		return
	_intro_done = true
	_status.text = "SABE QUE DESPERTASTE — avanza"
	_show_banner("SABE QUE DESPERTASTE", "los pasillos también te recuerdan", 1.8)


func _on_player_died(_hit: Dictionary) -> void:
	_finished = true
	_show_banner("TERMINADO", "siempre fuiste el mensaje de error", 3.0)
	await get_tree().create_timer(2.6).timeout
	get_tree().reload_current_scene()


func _on_ally_died(_hit: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_show_banner("NO DESPERTÓ", "algunas personas quedan conectadas para siempre", 3.0)
	await get_tree().create_timer(2.6).timeout
	get_tree().reload_current_scene()


func _victory() -> void:
	_finished = true
	_status.text = "NIVEL COMPLETADO — ESC para el menú"
	_show_banner("EL SUEÑO TERMINA", "por fin recordaste cerrar sesión", 8.0)
	get_tree().paused = false
	

func _show_banner(title: String, subtitle: String, duration: float) -> void:
	_banner.text = "[center][wave amp=16 freq=5]%s[/wave]\n[font_size=30][color=#9fd8ff]%s[/color][/font_size][/center]" % [title, subtitle]
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(maxf(0.0, duration - 0.8))
	tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: _banner.visible = false)
