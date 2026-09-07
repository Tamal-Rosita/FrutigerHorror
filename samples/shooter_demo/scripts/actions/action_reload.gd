extends ActionNode
class_name ActionReload

## RELOAD action (non-layered): starts the rig reload timer and drives the
## Reload state in the rifle locomotion state machine. The character plants
## during the reload clip (movement/jump are not whitelisted so the legs match
## the animation); ADS stays available.

var _character
var _rig


func _init() -> void:
	ACTION_ID = "RELOAD"
	interrupt_whitelist = [&"AIM"]


func _ready() -> void:
	_character = get_parent().get_parent()
	_rig = _character.get_node_or_null("CollisionShape3D/WeaponRig")
	if _rig and not _rig.reload_finished.is_connected(_on_reload_finished):
		_rig.reload_finished.connect(_on_reload_finished)


func can_play() -> bool:
	if not is_enabled or is_playing:
		return false
	if _rig == null:
		return false
	if _character is NovelCharacter and _character.is_busy:
		return false
	return _rig.can_reload()


func play(_params: Dictionary = {}) -> void:
	if is_playing or not can_play():
		return
	_rig.start_reload()
	super.play()


func stop() -> void:
	if not is_playing:
		return
	_rig.cancel_reload()
	super.stop()


func _on_reload_finished() -> void:
	if is_playing:
		super.stop()
