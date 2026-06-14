class_name Fx
extends Object
## One-shot juice helpers: particle bursts and positional screen shake.
## All particles are CPUParticles2D so the Web export stays predictable.


static func impact(parent: Node, pos: Vector2, z: int) -> void:
	## Orange sparks at a damage point.
	_burst(parent, pos, z, 10, Color(1.0, 0.72, 0.35), 90.0, 0.35, 2.2)


static func heal_burst(parent: Node, pos: Vector2, z: int) -> void:
	_burst(parent, pos, z, 8, Color(0.5, 1.0, 0.6), 45.0, 0.5, 2.0, Vector2(0, -40))


static func death(parent: Node, pos: Vector2, z: int, team: String) -> void:
	## Bigger pop when a unit dies: smoke puff + team-colored sparks.
	var spark := Color(0.55, 0.85, 1.0) if team == "mech" else Color(0.62, 0.95, 0.45)
	_burst(parent, pos, z, 16, spark, 140.0, 0.45, 2.6)
	_burst(parent, pos, z, 8, Color(0.42, 0.45, 0.5, 0.7), 35.0, 0.8, 5.0, Vector2(0, -30))


static func debris(parent: Node, pos: Vector2, z: int, big: bool) -> void:
	## Building / mountain chips.
	_burst(parent, pos, z, 14 if big else 8, Color(0.62, 0.5, 0.38), 110.0 if big else 70.0, 0.5, 2.4, Vector2(0, 220))
	if big:
		_burst(parent, pos, z, 6, Color(0.35, 0.35, 0.38, 0.8), 30.0, 0.9, 5.0, Vector2(0, -35))


static func muzzle(parent: Node, pos: Vector2, toward: Vector2, z: int) -> void:
	var dir := (toward - pos).normalized()
	var p := _particles(8, Color(1.0, 0.85, 0.45), 130.0, 0.18, 2.0, Vector2.ZERO)
	p.position = pos
	p.z_index = z
	p.direction = dir
	p.spread = 22.0
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func shake(node: Node2D, strength: float, duration: float = 0.25) -> void:
	## Decaying positional shake. Safe to overlap: the base position is
	## remembered on the node the first time and restored at the end.
	if not node.has_meta("fx_base_pos"):
		node.set_meta("fx_base_pos", node.position)
	var base: Vector2 = node.get_meta("fx_base_pos")
	var tw := node.create_tween()
	var steps := 6
	for i in steps:
		var fade := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade
		tw.tween_property(node, "position", base + off, duration / steps)
	tw.tween_property(node, "position", base, duration / steps)
	tw.tween_callback(func(): node.remove_meta("fx_base_pos"))


static func _burst(parent: Node, pos: Vector2, z: int, count: int, color: Color, speed: float, life: float, size: float, gravity: Vector2 = Vector2(0, 160)) -> void:
	var p := _particles(count, color, speed, life, size, gravity)
	p.position = pos
	p.z_index = z
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _particles(count: int, color: Color, speed: float, life: float, size: float, gravity: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = gravity
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p
