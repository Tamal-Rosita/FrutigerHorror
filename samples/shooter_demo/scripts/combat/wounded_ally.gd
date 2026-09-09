extends Node3D
class_name WoundedAlly

## The woman who did not wake up yet: wounded co-worker to defend. She is a
## real VRM character (Celia), stationary behind the cover, who whispers
## dream/office lines when the player is near, and can be killed by the
## enemies (group "Allies" + Health). Losing her fails the run.

signal downed(target: Node)

const NOVEL_BASE: PackedScene = preload("res://visual-novel/characters/novel_character_base.tscn")
const CELIA_MODEL: PackedScene = preload("res://visual-novel/GJDDM/characters/packed/celia.scn")
const CELIA_DCH: Resource = preload("res://dialogic/characters/Celia.dch")
const INTRO_TL: Resource = preload("res://dialogic/timelines/arena_intro.dtl")
const UI_THEME: Theme = preload("res://samples/shooter_demo/ui/shooter_theme.tres")

const LINES: Array[String] = [
	"Sigo viendo los íconos moverse cuando nadie los mira...",
	"Empezó en Excel. Las celdas no dejaban de *contarse* solas.",
	"La presentación dijo «Bienvenida» y las colinas empezaron a caminar.",
	"Ese rifle no estaba en mi escritorio ayer.",
	"No están enojados. Solo están... *por defecto*.",
	"No dejes que vuelvan a llegar a los cubículos.",
]

@export var player_path: NodePath
@export var whisper_range: float = 7.0

@onready var _health: Node = $Health

var _inner: NovelCharacter
var _line_index: int = 0
var _next_line_at: float = 0.0
var _subtitle: RichTextLabel
var _subtitle_tween: Tween


func _ready() -> void:
	add_to_group("Allies")
	_build_inner()
	_health.died.connect(_on_died)
	_build_subtitle()
	_next_line_at = Time.get_ticks_msec() / 1000.0 + 0.5


func _build_inner() -> void:
	_inner = NOVEL_BASE.instantiate() as NovelCharacter
	add_child(_inner)
	_inner.character_type = NovelCharacter.CharacterType.NPC
	_inner.has_monologue = false
	_inner.dialogic_character = CELIA_DCH
	_inner.vrm_scene = CELIA_MODEL
	_inner.default_pose_amount = 1.0 # wounded: keeps the standing pose, no locomotion
	_inner.character_timeline = INTRO_TL
	# Keep her in ControllableCharacter so player bullets pass through and the
	# novel-engine interaction prompt works normally (press X near her).
	var area := _inner.collision_shape.get_node_or_null("InteractionArea3D")
	if area:
		# Left enabled for the novel prompt; deferred to avoid signal-time flips.
		(area as Area3D).set_deferred("monitoring", true)
		(area as Area3D).set_deferred("monitorable", true)
	call_deferred("_repair_animation_root")
	await get_tree().create_timer(0.1).timeout
	if is_inside_tree():
		_repair_animation_root()


func _repair_animation_root() -> void:
	var tree: AnimationTree = _inner.get_node_or_null("AnimationTree")
	var model_container := _inner.get_node_or_null("CollisionShape3D/ModelContainer")
	if tree == null or model_container == null:
		return
	for child in model_container.get_children():
		if not child.find_children("*", "Skeleton3D", true, false).is_empty():
			tree.root_node = tree.get_path_to(child)
			return


func take_damage(amount: int, hit: Dictionary = {}) -> void:
	_health.take_damage(amount, hit)


func _on_died(_hit: Dictionary) -> void:
	downed.emit(self)
	_hide_subtitle()
	FxBank.popup(get_tree().current_scene, global_position + Vector3.UP * 1.8, "DEJÓ DE SOÑAR", Color(0.9, 0.4, 0.4))


func _process(_delta: float) -> void:
	if _health.get("is_dead"):
		return
	var player: Node3D = null
	if not player_path.is_empty():
		player = get_node_or_null(player_path) as Node3D
	if player == null or not is_instance_valid(player):
		return
	if Dialogic.current_timeline != null:
		return # the novel dialogue is on screen; whispers wait
	var now := Time.get_ticks_msec() / 1000.0
	var dist: float = player.global_position.distance_to(global_position)
	if dist <= whisper_range and now >= _next_line_at:
		_say_line()
		_next_line_at = now + randf_range(10.0, 16.0)


func _say_line() -> void:
	if _health.get("is_dead") or not is_inside_tree():
		return
	var line: String = LINES[_line_index % LINES.size()]
	_line_index += 1
	_show_subtitle("Celia", line)


func _build_subtitle() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AllySubtitles"
	add_child(layer)
	_subtitle = RichTextLabel.new()
	_subtitle.name = "Subtitle"
	_subtitle.theme = UI_THEME
	_subtitle.theme_type_variation = &"SubtitleRich"
	_subtitle.bbcode_enabled = true
	_subtitle.scroll_active = false
	_subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_top = -250.0
	_subtitle.offset_bottom = -70.0
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_subtitle.add_theme_constant_override("outline_size", 8)
	_subtitle.add_theme_constant_override("shadow_offset_x", 2)
	_subtitle.add_theme_constant_override("shadow_offset_y", 3)
	_subtitle.visible = false
	layer.add_child(_subtitle)


func _show_subtitle(speaker: String, text: String) -> void:
	if _subtitle_tween and _subtitle_tween.is_valid():
		_subtitle_tween.kill()
	_subtitle.text = "[center][color=#8fd8ff][b]%s:[/b][/color] %s[/center]" % [speaker, _to_bbcode(text)]
	_subtitle.modulate = Color(1, 1, 1, 0)
	_subtitle.visible = true
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.3)
	_subtitle_tween.tween_interval(3.6)
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.4)
	_subtitle_tween.tween_callback(func() -> void: _subtitle.visible = false)


## Converts *asterisk* spans into BBCode italics ([i]…[/i]).
static func _to_bbcode(line: String) -> String:
	var parts := line.split("*")
	var out := ""
	for i in parts.size():
		if i % 2 == 1:
			out += "[i]" + parts[i] + "[/i]"
		else:
			out += parts[i]
	return out


func _hide_subtitle() -> void:
	if _subtitle:
		_subtitle.visible = false
