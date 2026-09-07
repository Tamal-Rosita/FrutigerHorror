extends Object
class_name FxBank

## Lightweight runtime-only FX helpers (no assets required):
## tracer lines, impact flashes and muzzle light pulses.

const TRACER_WIDTH := 0.012
const TRACER_LIFE := 0.07
const IMPACT_LIFE := 0.14


static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var length := from.distance_to(to)
	if length <= 0.01:
		return

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TRACER_WIDTH, TRACER_WIDTH, length)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	mesh.mesh = box
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.global_position = (from + to) * 0.5
	mesh.look_at(to, Vector3.UP)

	var tween := mesh.create_tween()
	tween.tween_method(func(a: float) -> void: mat.albedo_color = Color(color.r, color.g, color.b, a), 0.95, 0.0, TRACER_LIFE)
	tween.tween_callback(mesh.queue_free)


static func impact(parent: Node, position: Vector3, normal: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.75, 0.3, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.3)
	mesh.mesh = sphere
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.global_position = position + normal * 0.04
	mesh.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

	var tween := mesh.create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(s: float) -> void: mesh.scale = Vector3.ONE * s, 0.25, 1.0, 0.04)
	tween.tween_method(func(a: float) -> void: mat.albedo_color = Color(1.0, 0.75, 0.3, a), 0.95, 0.0, IMPACT_LIFE)
	tween.chain().tween_callback(mesh.queue_free)


static func muzzle_flash(anchor: Node3D) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 6.0
	light.omni_range = 1.2
	anchor.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.06)
	tween.tween_callback(light.queue_free)


## Persistent-ish bullet hole decal on world surfaces (shows where shots land).
## The quad is oriented from the hit normal (parallel to the surface), robust
## for vertical and horizontal surfaces alike, and drawn double-sided.
static func bullet_hole(parent: Node, position: Vector3, normal: Vector3, life: float = 8.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var holder := Node3D.new()
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.05, 0.05, 0.05, 0.85)
	mat.roughness = 1.0
	mesh.mesh = quad
	mesh.material_override = mat
	holder.add_child(mesh)
	parent.add_child(holder)

	# Build an orthonormal basis with Z along the hit normal: the quad (which
	# faces +Z) then lies exactly parallel to the surface.
	var n := normal.normalized()
	var up_ref := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var x := up_ref.cross(n).normalized()
	var y := n.cross(x).normalized()
	holder.global_transform = Transform3D(Basis(x, y, n), position + n * 0.006)
	mesh.rotation.y = randf() * TAU # vary the hole's roll around the normal

	var tween := holder.create_tween()
	tween.tween_interval(maxf(0.0, life - 0.6))
	tween.tween_method(func(a: float) -> void: mat.albedo_color = Color(0.05, 0.05, 0.05, a), 0.85, 0.0, 0.6)
	tween.tween_callback(holder.queue_free)


## Floating world-space text popup (damage numbers, score gains).
static func popup(parent: Node, position: Vector3, text: String, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.7)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = position
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y + 0.6, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(a: float) -> void: label.modulate = Color(color.r, color.g, color.b, a), 1.0, 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)


## One-shot plasma/blood burst at a wound. Parented to a target node so it
## follows moving bodies (the target usually parents particles locally).
static func plasma_burst(parent: Node, world_pos: Vector3, world_normal: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = 16
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	particles.direction = world_normal.normalized()
	particles.spread = 55.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.6
	particles.gravity = Vector3(0, -5.0, 0)
	particles.scale_amount_min = 0.02
	particles.scale_amount_max = 0.05
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	particles.material_override = mat
	parent.add_child(particles)
	particles.global_position = world_pos
	var tween := particles.create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(particles.queue_free)
