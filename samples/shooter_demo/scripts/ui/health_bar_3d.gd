extends Node3D
class_name HealthBar3D

## World-space billboard health bar. Attach as a child of any node that has a
## "Health" child (player, allies). Anchors just above the model head using the
## character's GazeTarget height (the same face-height value NovelCharacter
## prints as "Character height"), falls back to `height` if no gaze target.

@export var caption: String = ""
@export var height: float = 1.95
@export var width: float = 0.6
## NodePath (relative to the bar's parent) of the character's GazeTarget.
@export var gaze_target_path: NodePath = NodePath("../GazeTarget")
@export var show_only_when_hurt: bool = false

const CAPTION_FONT: FontFile = preload("res://samples/shooter_demo/fonts/ChakraPetch-SemiBold.ttf")

const BG_COLOR := Color(0.05, 0.05, 0.07, 0.6)
const FULL_COLOR := Color(0.3, 0.85, 0.45, 0.95)
const EMPTY_COLOR := Color(0.9, 0.2, 0.2, 0.95)
## How far above the face the bar hovers.
const HEAD_PADDING := 0.14

var _health: Node
var _bg: MeshInstance3D
var _fill: MeshInstance3D
var _label: Label3D
var _ratio: float = 1.0


func _ready() -> void:
	position.y = _resolve_anchor_height()
	_build()
	_health = get_parent().get_node_or_null("Health")
	if _health and not _health.damaged.is_connected(_refresh):
		_health.damaged.connect(_refresh)
	if _health and not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)
	_refresh()


func _process(_delta: float) -> void:
	# Rotate the bar (yaw only) toward the active camera every frame so it is
	# always readable, whatever the orientation of the owner.
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length() < 0.01:
		return
	global_rotation.y = atan2(to_cam.x, to_cam.z)


func _resolve_anchor_height() -> float:
	if not gaze_target_path.is_empty():
		var gaze := get_parent().get_node_or_null(gaze_target_path) as Node3D
		if gaze:
			return gaze.position.y + HEAD_PADDING
	return height


func _build() -> void:
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.albedo_color = BG_COLOR
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_mat.no_depth_test = true
	_bg = MeshInstance3D.new()
	_bg.mesh = _make_quad(width + 0.05, 0.1)
	_bg.material_override = bg_mat
	add_child(_bg)

	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.albedo_color = FULL_COLOR
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.no_depth_test = true
	_fill = MeshInstance3D.new()
	_fill.mesh = _make_quad(width, 0.07)
	_fill.material_override = fill_mat
	add_child(_fill)
	_fill.position.z = -0.001

	if caption != "":
		_label = Label3D.new()
		_label.font = CAPTION_FONT
		_label.text = caption
		_label.font_size = 26
		_label.pixel_size = 0.006
		_label.modulate = Color(1, 1, 1, 0.85)
		_label.outline_size = 6
		_label.outline_modulate = Color(0, 0, 0, 0.8)
		_label.no_depth_test = true
		_label.position.y = 0.11
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_label)


func _make_quad(w: float, h: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	return quad


func _refresh(_a = null, _b = null) -> void:
	if _health == null or _health.get("is_dead"):
		visible = false
		return
	var max_hp: float = float(_health.get("max_health"))
	var hp: float = float(_health.get("current"))
	_ratio = clampf(hp / max_hp, 0.0, 1.0)
	if show_only_when_hurt and _ratio >= 1.0:
		visible = false
		return
	visible = true
	# Keep the left edge fixed while the bar shrinks from the right.
	_fill.scale.x = _ratio
	_fill.position.x = -(1.0 - _ratio) * width * 0.5
	var mat := _fill.material_override as StandardMaterial3D
	mat.albedo_color = FULL_COLOR.lerp(EMPTY_COLOR, 1.0 - _ratio)


func _on_died(_hit: Dictionary) -> void:
	visible = false
