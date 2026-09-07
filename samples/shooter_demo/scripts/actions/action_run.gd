extends ActionNode
class_name ActionRun

## Layered speed-modifier action (ACTION_ID "RUN").
##
## Framework usage (MCC): a layered ActionNode that plays on top of the
## layered "MOVE" action. Instead of racing MOVE over who writes the movement
## speed last each frame (the controller re-sends the base speed on every
## frame), this action toggles a multiplier that the movement state itself
## consumes when converting input into velocity (see
## MovementGroundedComplex.speed_multiplier). play() raises it, stop() lowers
## it back to 1.0 — no per-frame work needed and no ordering assumptions.
##
## The controller polls the run input every frame and calls play_action("RUN")
## / stop_action("RUN") accordingly, so play/stop must be idempotent.

## How much faster the character moves while running (multiplied into the
## character's base movement speed, e.g. 2.0 -> 3.5 with 1.75).
@export var speed_multiplier: float = 1.75

var _movement_class: MovementGroundedComplex


func _init() -> void:
	ACTION_ID = "RUN"
	IS_LAYERED = true


func _ready() -> void:
	# ActionContainer children live one level below the character root.
	var character: Node = get_parent().get_parent()
	var grounded: Node = character.find_child("GroundedMovement", false)
	if grounded is MovementGroundedComplex:
		_movement_class = grounded
	else:
		var manager: Node = character.find_child("MovementManager", false)
		grounded = manager.find_child("GroundedMovement", false) if manager else null
		if grounded is MovementGroundedComplex:
			_movement_class = grounded


func can_play() -> bool:
	if not is_enabled:
		return false
	if _movement_class == null:
		return false
	# Running only makes sense while the grounded movement state is active.
	var manager: MovementStateManager = _movement_class.get_parent() as MovementStateManager
	if manager and manager.active_state != _movement_class:
		return false
	return true


func play(_params: Dictionary = {}) -> void:
	if is_playing:
		return # controller polls RUN every frame while held
	_movement_class.speed_multiplier = speed_multiplier
	super.play()


func stop() -> void:
	if not is_playing:
		return
	_movement_class.speed_multiplier = 1.0
	super.stop()


func _exit_tree() -> void:
	# Safety net: never leave a character running if this node is removed/reconfigured.
	if _movement_class and _movement_class.speed_multiplier != 1.0:
		_movement_class.speed_multiplier = 1.0
