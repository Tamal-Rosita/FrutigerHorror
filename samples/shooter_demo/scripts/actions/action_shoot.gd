extends ActionNode
class_name ActionShoot

## SHOOT action (non-layered, impulse style like JUMP/DASH): each accepted play
## fires one round through the WeaponRig. Fire rate lives in the rig so the
## cooldown is a single canonical clock (the controller retries every frame
## while the trigger is held).

var _character
var _rig


func _init() -> void:
	ACTION_ID = "SHOOT"


func _ready() -> void:
	_character = get_parent().get_parent()
	_rig = _character.get_node_or_null("CollisionShape3D/WeaponRig")


func can_play() -> bool:
	if not is_enabled or is_playing:
		return false
	if _rig == null:
		return false
	if _character is NovelCharacter and _character.is_busy:
		return false # no firing during Dialogic timelines
	return _rig.can_fire_now()


func play(_params: Dictionary = {}) -> void:
	if is_playing or not can_play():
		return
	if not _rig.fire():
		return
	super.play()
	# Impulse style: actions must not enter and exit in the same frame.
	await get_tree().process_frame
	super.stop()


func get_state() -> Dictionary:
	return _rig.get_state() if _rig else {}


func play_dry() -> void:
	if _rig and not _rig.is_reloading:
		_rig.play_dry_sound()
