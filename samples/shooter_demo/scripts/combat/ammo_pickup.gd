extends Node3D
class_name AmmoPickup

## Rifle-bullet pickup: floats and spins in place; the player's WeaponRig
## gets reserve ammunition when touching it. One-shot consumable.

@export var amount: int = 60

var _consumed := false

@onready var _area: Area3D = $Area3D


func _ready() -> void:
	add_to_group("AmmoPickups")
	_area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	rotation.y += delta * 1.5
	position.y += sin(Time.get_ticks_msec() / 350.0) * delta * 0.1


func _on_body_entered(body: Node3D) -> void:
	if _consumed:
		return
	var rig := body.get_node_or_null("CollisionShape3D/WeaponRig")
	if rig == null:
		return
	_consumed = true
	rig.add_reserve(amount)
	FxBank.popup(get_tree().current_scene, global_position + Vector3.UP * 0.8, "+%d ROUNDS" % amount, Color(0.85, 0.95, 0.5))
	queue_free()
