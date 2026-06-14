class_name BattleBackdrop
extends CanvasLayer
## Atmospheric layer behind the battle board: gradient glow + drifting motes.

const SHADER := preload("res://src/view/fx/backdrop.gdshader")


func _ready() -> void:
	layer = -10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)

	add_child(_motes(Color(0.45, 0.85, 0.9, 0.35), 26, 6.0, 1.6))
	add_child(_motes(Color(1.0, 0.72, 0.4, 0.28), 14, 9.0, 2.2))


func _motes(color: Color, amount: int, lifetime: float, point_scale: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(640, 420)
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime  # field is already populated on the first frame
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(660, 380)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = point_scale * 0.6
	p.scale_amount_max = point_scale
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p
