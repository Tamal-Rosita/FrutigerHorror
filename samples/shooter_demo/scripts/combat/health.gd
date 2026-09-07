extends Node
class_name Health

## Generic health pool used by targets, destructible props and (later) bots.

signal damaged(amount: int, hit: Dictionary)
signal died(hit: Dictionary)

@export var max_health: int = 100

var current: int = 100
var is_dead: bool = false


func _ready() -> void:
	current = max_health


func take_damage(amount: int, hit: Dictionary = {}) -> void:
	if is_dead or amount <= 0:
		return
	current = maxi(0, current - amount)
	damaged.emit(amount, hit)
	if current <= 0:
		is_dead = true
		died.emit(hit)


func reset() -> void:
	current = max_health
	is_dead = false
