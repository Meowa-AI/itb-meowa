class_name PostFx
extends CanvasLayer
## Screen-space grade + vignette over every screen. Added once by Game.

const SHADER := preload("res://src/view/fx/post_fx.gdshader")


func _ready() -> void:
	layer = 90
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)
