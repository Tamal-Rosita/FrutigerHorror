class_name ThirdPersonCamera extends Node3D

## camera functionality

@export_group("CAM")
@export var sensitivity_x : float = 0.005
@export var sensitivity_y : float = 0.005
@export var normal_fov : float = 45.0
@export var run_fov : float = 75.0
@export var maze_fov : float = 90.0

# TODO: Create derived class for shooter camera that extends this class.
@export_group("ADS")
@export var ads_fov : float = 42.0
@export var ads_spring_length : float = 0.8
@export var ads_blend_speed : float = 10.0

@export_group("Spring Arm")
@export var auto_set_len : bool = false

enum FOV {NORMAL, RUN, MAZE}
const CAMERA_BLEND : float = 0.05
## Recoil kicks accumulate as an offset that decays back to zero. Only the
## kick is recovered — the player's own aim is never pulled (framerate
## independent: exponential decay, each frame removes a fraction of the
## remaining offset).
const RECOIL_RECOVER_RATE: float = 7.0
## Safety cap so sustained fire can't climb or drift sideways unbounded.
const RECOIL_MAX_OFFSET: float = deg_to_rad(12.0)

var _aim_active: bool = false
var _aim_restore_fov: float = -1.0
var _aim_restore_length: float = -1.0
## Remaining recoil to ease out of the view: x = pitch, y = yaw (radians).
var _recoil_offset := Vector2.ZERO

@onready var spring_arm : SpringArm3D = $SpringArm3D
@onready var camera : PhantomCamera3D = $SpringArm3D/PhantomCamera3D


func _ready() -> void:
	# prevent spring arm from colliding with owning character
	spring_arm.add_excluded_object(get_parent().get_rid()) 
	
	if auto_set_len:
		set_length(spring_arm.global_position.distance_to(camera.global_position))
	
func override_priority()-> void:
	camera.priority_override = true
	
func reset_priority() -> void:
	camera.priority = 0
		
func set_priority(value: int) -> void:
	camera.priority = value

func set_length(value: float) -> void:
	spring_arm.spring_length = value
	
func set_fov(value: float) -> void:
	camera.fov = value

func _process(delta: float) -> void:
	_update_ads(delta)
	_update_recoil(delta)

## Aim-down-sights: smoothly blend FOV and spring-arm length while active,
## easing back to the values captured when aiming started once released.
func set_aim_active(active: bool) -> void:
	if active == _aim_active:
		return
	_aim_active = active
	if active:
		_aim_restore_fov = camera.fov
		_aim_restore_length = spring_arm.spring_length

## Adds a view kick (degrees). Positive pitch looks up. The kick lands
## instantly; the leftover offset eases back out over the next moments, while
## mouse look keeps full control of the view at all times.
func add_recoil(pitch_deg: float, yaw_deg: float) -> void:
	var pitch: float = deg_to_rad(pitch_deg)
	var yaw: float = deg_to_rad(yaw_deg)
	rotation.x = clampf(rotation.x + pitch, -PI / 4.0, PI / 4.0)
	rotation.y += yaw
	_recoil_offset += Vector2(pitch, yaw)
	_recoil_offset = _recoil_offset.limit_length(RECOIL_MAX_OFFSET)
	if spring_arm.top_level:
		spring_arm.rotation = rotation

func _update_ads(delta: float) -> void:
	var target_fov: float = ads_fov if _aim_active else _aim_restore_fov
	var target_length: float = ads_spring_length if _aim_active else _aim_restore_length
	if target_fov > 0.0 and not is_equal_approx(camera.fov, target_fov):
		set_fov(lerpf(camera.fov, target_fov, 1.0 - exp(-delta * ads_blend_speed)))
	if target_length > 0.0 and not is_equal_approx(spring_arm.spring_length, target_length):
		spring_arm.spring_length = lerpf(spring_arm.spring_length, target_length, 1.0 - exp(-delta * ads_blend_speed))

func _update_recoil(delta: float) -> void:
	if _recoil_offset.is_zero_approx():
		return
	var damp: float = 1.0 - exp(-delta * RECOIL_RECOVER_RATE)
	var back := _recoil_offset * damp
	_recoil_offset -= back
	rotation.x = clampf(rotation.x - back.x, -PI / 4.0, PI / 4.0)
	rotation.y -= back.y
	if _recoil_offset.length() < deg_to_rad(0.02):
		# Snap-finish: take out the final sliver precisely.
		rotation.x = clampf(rotation.x - _recoil_offset.x, -PI / 4.0, PI / 4.0)
		rotation.y -= _recoil_offset.y
		_recoil_offset = Vector2.ZERO
	if spring_arm.top_level:
		spring_arm.rotation = rotation

func _physics_process(_delta: float) -> void:
	smooth_move_y(0.07) # 0.7 just feels good

func change_fov(setting: FOV) -> void:
	match setting:
		FOV.NORMAL:
			set_fov(normal_fov)
		FOV.RUN:
			set_fov(run_fov)
		FOV.MAZE: 
			set_fov(maze_fov)

func rotate_view(vec: Vector2) -> void:
	rotation.x -= vec.y * sensitivity_y
	rotation.x = clampf(rotation.x, -PI/4, PI/4)
	rotation.y += -vec.x * sensitivity_x
	if spring_arm.top_level:
		spring_arm.rotation = rotation

func set_direction(vec: Vector2) -> void:
	transform = transform.looking_at(Vector3(vec.x, position.y, vec.y))
	if spring_arm.top_level:
		spring_arm.rotation = rotation

func smooth_move_y(weight) -> void:
	# note: spring_arm is marked as top level so transform is not inherited from parent
	# this allows smoothing of movement
	spring_arm.global_position.x = global_position.x
	spring_arm.global_position.y = lerpf(spring_arm.global_position.y, global_position.y, weight)
	spring_arm.global_position.z = global_position.z

func get_cam_forward() -> Vector3:
	return -camera.get_global_transform().basis.z 
