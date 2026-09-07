extends CanvasLayer
class_name ShooterSettings

## Pause menu (ESC): main actions (Resume / Restart / Quit) plus two submenus:
## - Settings (public): sound volume
## - Debug (developer): camera distance / shoulder offset / mouse sensitivity /
##   ADS FOV — the Phase-1 tuning rig, kept out of the players' way.
## Persists to user://shooter_menu.cfg.

@export var player_path: NodePath

const PAUSE_ACTION := "pause"
const CFG_PATH := "user://shooter_menu.cfg"

@onready var _main_panel: Control = $Panel/Margin/Main
@onready var _settings_panel: Control = $Panel/Margin/Settings
@onready var _debug_panel: Control = $Panel/Margin/Debug
@onready var _volume_slider: HSlider = $Panel/Margin/Settings/RowVolume/Slider
@onready var _volume_value: Label = $Panel/Margin/Settings/RowVolume/Value
@onready var _distance_slider: HSlider = $Panel/Margin/Debug/RowDistance/Slider
@onready var _distance_value: Label = $Panel/Margin/Debug/RowDistance/Value
@onready var _shoulder_slider: HSlider = $Panel/Margin/Debug/RowShoulder/Slider
@onready var _shoulder_value: Label = $Panel/Margin/Debug/RowShoulder/Value
@onready var _sens_slider: HSlider = $Panel/Margin/Debug/RowSens/Slider
@onready var _sens_value: Label = $Panel/Margin/Debug/RowSens/Value
@onready var _ads_fov_slider: HSlider = $Panel/Margin/Debug/RowAdsFov/Slider
@onready var _ads_fov_value: Label = $Panel/Margin/Debug/RowAdsFov/Value

var _camera: Node3D
var _cfg := ConfigFile.new()
var _pending_camera: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	_cfg_to_sliders()
	_apply_master_volume()
	var player := get_node_or_null(player_path) if not player_path.is_empty() else null
	if player:
		_camera = player.get_node_or_null("ThirdPersonCamera")
	_bind_slider(_volume_slider, _volume_value, "%.0f dB", _apply_volume)
	_bind_slider(_distance_slider, _distance_value, "%.1f m", _apply_distance)
	_bind_slider(_shoulder_slider, _shoulder_value, "%.2f", _apply_shoulder)
	_bind_slider(_sens_slider, _sens_value, "%.3f", _apply_sensitivity)
	_bind_slider(_ads_fov_slider, _ads_fov_value, "%.0f fov", _apply_ads_fov)
	($Panel/Margin/Main/Resume as Button).pressed.connect(toggle_pause)
	($Panel/Margin/Main/Restart as Button).pressed.connect(restart)
	($Panel/Margin/Main/Quit as Button).pressed.connect(_quit)
	($Panel/Margin/Main/SettingsButton as Button).pressed.connect(func() -> void: _show(_settings_panel))
	($Panel/Margin/Main/DebugButton as Button).pressed.connect(func() -> void: _show(_debug_panel))
	($Panel/Margin/Settings/Back as Button).pressed.connect(func() -> void: _show(_main_panel))
	($Panel/Margin/Debug/Back as Button).pressed.connect(func() -> void: _show(_main_panel))
	_show(_main_panel)


func _process(_delta: float) -> void:
	if _pending_camera and _camera == null:
		var player := get_node_or_null(player_path) if not player_path.is_empty() else null
		if player:
			_camera = player.get_node_or_null("ThirdPersonCamera")
		if _camera:
			_pending_camera = false
			_apply_saved_camera()
	if Input.is_action_just_pressed(PAUSE_ACTION):
		if _main_panel.visible or _settings_panel.visible or _debug_panel.visible:
			if _main_panel.visible:
				toggle_pause()
			else:
				_show(_main_panel)
		else:
			toggle_pause()


func toggle_pause() -> void:
	if get_tree().paused:
		_resume()
	else:
		_pause()


func restart() -> void:
	_save_config()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit() -> void:
	_save_config()
	get_tree().paused = false
	get_tree().quit()


func _pause() -> void:
	_sync_sliders_from_camera()
	_show(_main_panel)
	$Panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _resume() -> void:
	_show(_main_panel)
	$Panel.visible = false
	_save_config()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show(panel: Control) -> void:
	_main_panel.visible = panel == _main_panel
	_settings_panel.visible = panel == _settings_panel
	_debug_panel.visible = panel == _debug_panel


# --- Persistence ------------------------------------------------------------

func _load_config() -> void:
	if _cfg.load(CFG_PATH) != OK:
		_cfg.set_value("options", "master_volume_db", 0.0)
		_cfg.set_value("options", "camera_distance", 2.4)
		_cfg.set_value("options", "shoulder_offset", 0.35)
		_cfg.set_value("options", "sensitivity", 0.005)
		_cfg.set_value("options", "ads_fov", 40.0)


func _save_config() -> void:
	_cfg.save(CFG_PATH)


func _cfg_to_sliders() -> void:
	_volume_slider.value = _cfg.get_value("options", "master_volume_db", 0.0)
	_distance_slider.value = _cfg.get_value("options", "camera_distance", 2.4)
	_shoulder_slider.value = _cfg.get_value("options", "shoulder_offset", 0.35)
	_sens_slider.value = _cfg.get_value("options", "sensitivity", 0.005)
	_ads_fov_slider.value = _cfg.get_value("options", "ads_fov", 40.0)


func _apply_saved_camera() -> void:
	if _camera == null:
		return
	_apply_distance(_distance_slider.value)
	_apply_shoulder(_shoulder_slider.value)
	_apply_sensitivity(_sens_slider.value)
	_apply_ads_fov(_ads_fov_slider.value)


# --- Sliders ----------------------------------------------------------------

func _bind_slider(slider: HSlider, value_label: Label, fmt: String, applier: Callable) -> void:
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = fmt % v
		applier.call(v))


func _sync_sliders_from_camera() -> void:
	if _camera == null:
		return
	_distance_slider.set_value_no_signal(_camera.default_camera_distance)
	_shoulder_slider.set_value_no_signal(_camera.shoulder_offset)
	_sens_slider.set_value_no_signal(_camera.sensitivity_x)
	_ads_fov_slider.set_value_no_signal(_camera.ads_fov)


func _apply_volume(v: float) -> void:
	_cfg.set_value("options", "master_volume_db", v)
	_apply_master_volume()


func _apply_master_volume() -> void:
	var db: float = _cfg.get_value("options", "master_volume_db", 0.0)
	AudioServer.set_bus_volume_db(0, db)


func _apply_distance(v: float) -> void:
	_cfg.set_value("options", "camera_distance", v)
	if _camera and _camera.has_method("set_camera_distance"):
		_camera.set_camera_distance(v)


func _apply_shoulder(v: float) -> void:
	_cfg.set_value("options", "shoulder_offset", v)
	if _camera:
		_camera.shoulder_offset = v


func _apply_sensitivity(v: float) -> void:
	_cfg.set_value("options", "sensitivity", v)
	if _camera:
		_camera.sensitivity_x = v
		_camera.sensitivity_y = v


func _apply_ads_fov(v: float) -> void:
	_cfg.set_value("options", "ads_fov", v)
	if _camera:
		_camera.ads_fov = v
