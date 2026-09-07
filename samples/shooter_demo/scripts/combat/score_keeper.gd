extends Node
class_name ScoreKeeper

## Level-side scoring for the gallery. Subscribes to the player WeaponRig for
## shots/hits (accuracy) and receives target down events through register_down.

signal stats_changed

@export var player_path: NodePath

var score: int = 0
var shots: int = 0
var hits: int = 0

var _rig: Node = null


func _ready() -> void:
	add_to_group("ScoreKeeper")
	if player_path == null or player_path.is_empty():
		return
	var player := get_node_or_null(player_path)
	if player == null:
		push_warning("ScoreKeeper: player not found at ", player_path)
		return
	_rig = player.get_node_or_null("CollisionShape3D/WeaponRig")
	if _rig and not _rig.shot_fired.is_connected(_on_shot_fired):
		_rig.shot_fired.connect(_on_shot_fired)


func register_down(target: Node) -> void:
	score += int(target.get("points") if target.get("points") else 0)
	stats_changed.emit()


func _on_shot_fired(result: Dictionary) -> void:
	shots += 1
	if result.get("damaged", false):
		hits += 1
	stats_changed.emit()


func get_accuracy() -> float:
	return float(hits) / float(shots) if shots > 0 else 1.0
