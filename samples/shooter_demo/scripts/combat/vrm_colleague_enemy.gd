extends Node3D
class_name VrmColleagueEnemy

## VRM colleague enemy: builds a NovelCharacter at runtime (like ShooterPlayer),
## swaps in a packed VRM colleague (georgino) and points its AnimationTree at
## the colleague clone of the working novel blend tree. Movement is driven
## through the standard MCC path (ActionContainer "MOVE" per frame → the
## character's own physics + animation tree), so walking and stopping behave
## exactly like every other NovelCharacter NPC. Attack/death states will be
## added to the colleague tree later (owner provides the clips).
##
## The inner character leaves the ControllableCharacter group so bullets can
## hit it; its Dialogic interaction layer is disabled; it joins
## ShootableTargets/Enemies to reuse the whole damage/score pipeline.

signal downed(target: Node)

const NOVEL_BASE: PackedScene = preload("res://visual-novel/characters/novel_character_base.tscn")
const GEORGINO_MODEL: PackedScene = preload("res://visual-novel/GJDDM/characters/packed/georgino.scn")
const GEORGINO_DCH: Resource = preload("res://dialogic/characters/Georgino.dch")
@export var points: int = 150
@export var chase_speed: float = 2.4
@export var attack_range: float = 1.4
@export var attack_damage: int = 10
@export var attack_interval: float = 1.0
@export var player_path: NodePath

@onready var _health: Node = $Health

var _inner: NovelCharacter
var alive: bool = true
var _attack_cooldown: float = 0.0
var _target: Node3D = null


func _ready() -> void:
	add_to_group("ShootableTargets")
	add_to_group("Enemies")
	_build_inner()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _build_inner() -> void:
	_inner = NOVEL_BASE.instantiate() as NovelCharacter
	add_child(_inner)
	# Same config dance as ShooterPlayer: swap model + identity.
	_inner.character_type = NovelCharacter.CharacterType.NPC
	_inner.has_monologue = false
	_inner.dialogic_character = GEORGINO_DCH
	_inner.vrm_scene = GEORGINO_MODEL
	_inner.default_pose_amount = 0.0
	_inner.speed = chase_speed
	_inner.remove_from_group("ControllableCharacter")
	var area := _inner.collision_shape.get_node_or_null("InteractionArea3D")
	if area:
		(area as Area3D).monitoring = false
		(area as Area3D).monitorable = false
	# Tiny drop-in so the character's own physics settles it on the floor.
	_inner.position.y = 0.25
	# The inner character already runs the standard novel blend tree (the one
	# every VN NPC uses). Just re-anchor it to the real model root and force
	# the locomotion path; a colleague-specific clone can come later with the
	# attack/death states.
	var tree: AnimationTree = _inner.get_node("AnimationTree")
	_reset_pose(tree)
	call_deferred("_finish_setup")


func _finish_setup() -> void:
	if not is_inside_tree():
		return
	var tree: AnimationTree = _inner.get_node("AnimationTree")
	_reset_pose(tree)
	_repair_animation_root()


func _reset_pose(tree: AnimationTree) -> void:
	tree.set("parameters/LocomotionBlend/blend_amount", 1.0)
	tree.set("parameters/Locomotion/conditions/JUMP", false)
	tree.set("parameters/Locomotion/Motion/blend_position", -0.1)
	if tree.has_method("set_pose"):
		tree.set_pose("idle", 0.0)


func _repair_animation_root() -> void:
	var tree: AnimationTree = _inner.get_node_or_null("AnimationTree")
	var model_container := _inner.get_node_or_null("CollisionShape3D/ModelContainer")
	if tree == null or model_container == null:
		return
	for child in model_container.get_children():
		if child.find_children("*", "Skeleton3D", true, false).is_empty() == false:
			tree.root_node = tree.get_path_to(child)
			return


func take_damage(amount: int, hit: Dictionary = {}) -> void:
	_health.take_damage(amount, hit)


func _on_damaged(amount: int, hit: Dictionary) -> void:
	var pos: Vector3 = hit.get("position", global_position + Vector3.UP * 1.2)
	FxBank.popup(get_tree().current_scene, pos, "-%d" % amount, Color(1.0, 0.25, 0.25))
	FxBank.plasma_burst(_inner, pos, hit.get("normal", Vector3.UP), Color(0.85, 0.12, 0.18))


func _on_died(_hit: Dictionary) -> void:
	if not alive:
		return
	alive = false
	downed.emit(self)
	_inner.velocity = Vector3.ZERO
	_inner.collision_layer = 0
	var container := _inner.get_node("ActionContainer")
	container.play_action("MOVE", {"input_direction": Vector3.ZERO})
	var sk := get_tree().get_first_node_in_group("ScoreKeeper")
	if sk and sk.has_method("register_down"):
		sk.register_down(self)
	var pos: Vector3 = _inner.global_position + Vector3.UP * 1.4
	FxBank.popup(get_tree().current_scene, pos, "+%d" % points, Color(0.85, 0.8, 0.4))
	# Death anim pending from the owner; tilt-and-sink until the clip arrives.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_inner, "rotation", Vector3(deg_to_rad(-80.0), 0, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_inner, "position:y", -0.5, 0.5)
	await tween.finished
	queue_free()


func _physics_process(delta: float) -> void:
	if not alive or _inner == null or not is_instance_valid(_inner):
		return
	_resolve_target()
	if _target == null or not is_instance_valid(_target):
		_stop_moving()
		return
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	var to_target := _target.global_position - _inner.global_position
	to_target.y = 0.0
	var dist := to_target.length()
	var container := _inner.get_node("ActionContainer")
	if dist > attack_range and dist > 0.01:
		# Standard NPC-style drive: the character's own movement state + the
		# colleague tree turn this into walking toward the victim.
		container.play_action("MOVE", {"input_direction": to_target.normalized()})
	else:
		container.play_action("MOVE", {"input_direction": Vector3.ZERO})
		if dist > 0.01 and _attack_cooldown <= 0.0:
			_attack_target()
			_attack_cooldown = attack_interval


func _stop_moving() -> void:
	if not is_instance_valid(_inner):
		return
	var container := _inner.get_node("ActionContainer")
	container.play_action("MOVE", {"input_direction": Vector3.ZERO})


func _attack_target() -> void:
	var health := _target.get_node_or_null("Health")
	if health and health.has_method("take_damage"):
		health.take_damage(attack_damage, {"position": _target.global_position + Vector3.UP, "attacker": self})


func _resolve_target() -> void:
	var player := get_node_or_null(player_path) if not player_path.is_empty() else null
	var best: Node3D = player as Node3D
	var best_dist := INF
	var origin: Vector3 = _inner.global_position if is_instance_valid(_inner) else global_position
	if best and is_instance_valid(best):
		best_dist = best.global_position.distance_to(origin)
	for ally in get_tree().get_nodes_in_group("Allies"):
		var node := ally as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var ally_health := node.get_node_or_null("Health")
		if ally_health and ally_health.get("is_dead"):
			continue
		var d := node.global_position.distance_to(origin)
		if d < best_dist:
			best_dist = d
			best = node
	_target = best
