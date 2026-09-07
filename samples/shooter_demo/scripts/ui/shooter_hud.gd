extends CanvasLayer
class_name ShooterHud

## Minimal shooter HUD: crosshair with live spread, ammo readout, reload/empty
## prompts, hitmarker flash and score/accuracy readout. Reads only public
## Action/WeaponRig APIs plus the level ScoreKeeper (group lookup).

@export var player_path: NodePath

const LOW_AMMO_COLOR := Color(1.0, 0.45, 0.2)
const SPREAD_PX_PER_DEG := 5.0

@onready var _canvas: ShooterCanvas = $Canvas
@onready var _ammo_label: Label = $Canvas/AmmoLabel
@onready var _status_label: Label = $Canvas/StatusLabel
@onready var _score_label: Label = $Canvas/ScoreLabel
@onready var _stats_label: Label = $Canvas/StatsLabel

var _hitmarker_time: float = 0.0
var _player: Node
var _shoot: Variant = null
var _rig: Node = null


func _ready() -> void:
	if player_path == null or player_path.is_empty():
		return
	_player = get_node_or_null(player_path)
	if _player == null:
		push_warning("ShooterHud: player not found at ", player_path)
		return
	var container: Node = _player.get_node_or_null("ActionContainer")
	if container:
		_shoot = container.get_action("SHOOT")
	_rig = _player.get_node_or_null("CollisionShape3D/WeaponRig")
	if _rig and not _rig.target_hit.is_connected(_on_target_hit):
		_rig.target_hit.connect(_on_target_hit)


func _process(delta: float) -> void:
	if _hitmarker_time > 0.0:
		_hitmarker_time = maxf(0.0, _hitmarker_time - delta)

	var ammo_text := "--"
	var status := ""
	var spread_deg: float = 1.2
	var empty := false

	if _shoot != null:
		var state: Dictionary = _shoot.get_state()
		ammo_text = str(state.get("ammo", 0)) + " / " + str(state.get("reserve", 0))
		empty = state.get("ammo", 0) <= 0
		var reloading: bool = state.get("reloading", false)
		if reloading:
			status = "RELOADING..."
		elif empty:
			status = "Press R to reload"
	if _rig and _rig.has_method("get_current_spread_degrees"):
		spread_deg = _rig.get_current_spread_degrees()

	_ammo_label.text = ammo_text
	_ammo_label.add_theme_color_override("font_color", LOW_AMMO_COLOR if empty else Color.WHITE)
	_status_label.text = status
	_status_label.visible = status != ""

	var sk := get_tree().get_first_node_in_group("ScoreKeeper")
	if sk:
		_score_label.text = "SCORE  %05d" % int(sk.score)
		_stats_label.text = "HITS %d / %d   ACC %d%%" % [int(sk.hits), int(sk.shots), roundi(sk.get_accuracy() * 100.0)]
	else:
		_score_label.text = "SCORE  00000"
		_stats_label.text = ""

	_canvas.spread_px = spread_deg * SPREAD_PX_PER_DEG
	_canvas.hitmarker_active = _hitmarker_time > 0.0
	_canvas.color = Color(1.0, 0.4, 0.35) if empty else Color(1, 1, 1, 0.9)
	_canvas.queue_redraw()


func _on_target_hit(_position: Vector3, _damage: float) -> void:
	_hitmarker_time = 0.18
