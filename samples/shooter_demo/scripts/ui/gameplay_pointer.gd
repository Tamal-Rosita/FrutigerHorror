extends Node
class_name GameplayPointer

## Pointer policy for the shooter demo levels.
##
## Why this exists: mouse look lives in the controller stack
## (ControllerPlayer._unhandled_input -> process_unhandled_input ->
## ThirdPersonCamera.rotate_view) and is gated on MOUSE_MODE_CAPTURED. The VN
## pointer_capture helper only re-captures after an LMB press or the talk
## action, so whenever the level starts (or a menu/dialogue leaves the pointer
## free) mouse rotation is silently dead while gamepad look still works.
##
## This node keeps the pointer CAPTURED during gameplay and only releases it
## while a Dialogic timeline is running or the pause menu is open.

func _ready() -> void:
	# Keep running while the pause menu pauses the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var free_pointer: bool = get_tree().paused or Dialogic.current_timeline != null
	var target := Input.MOUSE_MODE_VISIBLE if free_pointer else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != target:
		Input.mouse_mode = target
