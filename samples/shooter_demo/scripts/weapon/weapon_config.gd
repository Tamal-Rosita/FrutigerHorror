extends Resource
class_name WeaponConfig

## Weapon balance data for the shooter demo (single rifle for v1; swap the
## resource later to add arsenal variety without touching the rig code).

@export var display_name: String = "Rifle"

## Damage applied to shootable targets.
@export var damage: float = 34.0

## Rounds per second while the trigger is held.
@export var fire_rate: float = 9.0

## true: fire while trigger held; false: one shot per press.
@export var automatic: bool = true

@export var mag_size: int = 30
@export var reserve_size: int = 120
@export var reload_time: float = 1.4

## Hip-fire and ADS spread (degrees around the aim ray).
@export var spread_degrees: float = 1.2
@export var aim_spread_degrees: float = 0.35

## Bloom: spread grows per shot and decays back while not firing.
@export var bloom_per_shot: float = 0.7
@export var bloom_decay_rate: float = 3.0 # degrees per second
@export var max_bloom: float = 4.5

## View kick per shot in degrees.
@export var recoil_pitch: float = 1.0
@export var recoil_yaw: float = 0.45

## ADS camera zoom (fov degrees) and spring arm length used while aiming.
@export var ads_fov: float = 42.0
@export var ads_spring_length: float = 0.8

@export var max_range: float = 200.0
@export var tracer_color: Color = Color(1.0, 0.92, 0.55)
