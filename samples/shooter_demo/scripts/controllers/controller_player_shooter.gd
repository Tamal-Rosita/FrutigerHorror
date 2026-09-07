extends ControllerPlayerThirdPerson
class_name ControllerPlayerShooter

## Brain for the shooter player. Adds trigger / ADS / reload input on top of
## ControllerPlayerThirdPerson (movement, run, jump, dash and camera look).
##
## Input:
## - fire: LMB  (auto: held; semi: per press)
## - aim : RMB  (hold to ADS)
## - reload: R  (manual) + auto-reload when pulling the trigger on an empty mag

var _fire_prev: bool = false


func _process(delta: float) -> void:
	super._process(delta)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_fire_prev = false
		return

	var fire_held: bool = Input.is_action_pressed("fire")
	var shoot = _get_shoot_action()
	var automatic: bool = true
	if shoot != null:
		automatic = bool(shoot.get_state().get("automatic", true))
	if fire_held and (automatic or not _fire_prev):
		_try_fire()
	_fire_prev = fire_held

	if Input.is_action_pressed("aim"):
		_action_container.play_action("AIM")
	else:
		_action_container.stop_action("AIM")

	if Input.is_action_just_pressed("reload"):
		if not _action_container.play_action("RELOAD"):
			pass # can_play rejected (e.g. mag full or no reserve)


func evaluate_input(key: String, double_tap: bool = false) -> void:
	match key:
		"fire":
			if _input_tracking[key]:
				_try_fire()
		"aim":
			if _input_tracking[key]:
				_action_container.play_action("AIM")
			else:
				_action_container.stop_action("AIM")
		"reload":
			if _input_tracking[key]:
				_action_container.play_action("RELOAD")
		_:
			super.evaluate_input(key, double_tap)


func _get_shoot_action():
	if _action_container == null:
		return null
	return _action_container.get_action("SHOOT")


func _try_fire() -> void:
	var shoot = _get_shoot_action()
	if shoot == null:
		return
	var state: Dictionary = shoot.get_state()
	if state.get("reloading", false):
		return
	if state.get("ammo", 0) <= 0:
		if state.get("reserve", 0) > 0:
			_action_container.play_action("RELOAD") # auto-reload on empty
		else:
			shoot.play_dry()
		return
	_action_container.play_action("SHOOT")
