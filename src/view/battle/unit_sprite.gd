class_name UnitSprite
extends Node2D
## Visual for one BUnit: sprite + HP pips. Kept in sync via sync_to().

const FRAME_SIZE := Vector2i(64, 64)
const FRAME_COUNT := 4
const ANIMATION_FPS := {
	"idle": 5.0,
	"attack": 16.0,
	"hit": 16.0,
}
const FLASH_SHADER := preload("res://src/view/fx/flash.gdshader")
const TEXTURES := {
	"prime": preload("res://assets/sprites/prime.png"),
	"artillery": preload("res://assets/sprites/artillery.png"),
	"science": preload("res://assets/sprites/science.png"),
	"hornet": preload("res://assets/sprites/hornet.png"),
	"firefly": preload("res://assets/sprites/firefly.png"),
	"scorpion": preload("res://assets/sprites/scorpion.png"),
	"scarab": preload("res://assets/sprites/scarab.png"),
	"hornet_leader": preload("res://assets/sprites/hornet_leader.png"),
}

var def_id: String
var unit_id: int
var team: String
var hp: int = 0
var max_hp: int = 0
var _sprite: Sprite2D
var _current_animation := ""
var _frame := 0
var _frame_time := 0.0


func setup(u: BUnit) -> void:
	def_id = u.def_id
	unit_id = u.id
	team = u.team
	_sprite = Sprite2D.new()
	# Feet at the tile center: sprite is 64x64, units stand in lower half.
	_sprite.offset = Vector2(0, -24)
	_sprite.show_behind_parent = true  # HP pips (parent _draw) stay on top
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	_sprite.material = mat
	add_child(_sprite)
	_play_animation("idle")
	sync_to(u)


func sync_to(u: BUnit) -> void:
	hp = u.hp
	max_hp = u.max_hp
	position = Iso.to_screen(u.pos)
	z_index = Iso.sort_z(u.pos)
	visible = u.alive
	queue_redraw()


func flash(color: Color) -> void:
	## White-hot pop that decays into the given tint, then back to normal.
	var mat := _sprite.material as ShaderMaterial
	mat.set_shader_parameter("flash_color", Vector3(color.r, color.g, color.b).lerp(Vector3.ONE, 0.55))
	mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.28)


static func animation_path(unit_id_: String, animation_name: String) -> String:
	return "res://assets/sprites/animations/%s/%s.png" % [unit_id_, animation_name]


func current_animation() -> String:
	return _current_animation


func play_attack() -> void:
	_play_animation("attack")


func play_hit() -> void:
	_play_animation("hit")


func _process(delta: float) -> void:
	if _sprite == null or _current_animation == "":
		return
	_frame_time += delta
	var frame_duration: float = 1.0 / ANIMATION_FPS.get(_current_animation, 8.0)
	while _frame_time >= frame_duration:
		_frame_time -= frame_duration
		_frame += 1
		if _frame >= FRAME_COUNT:
			if _current_animation == "idle":
				_frame = 0
			else:
				_play_animation("idle")
				return
		_apply_frame()


func _play_animation(animation_name: String) -> void:
	var tex := _animation_texture(def_id, animation_name)
	if tex == null:
		_sprite.texture = TEXTURES[def_id]
		_sprite.region_enabled = false
		_current_animation = animation_name
		return
	_sprite.texture = tex
	_sprite.region_enabled = true
	_current_animation = animation_name
	_frame = 0
	_frame_time = 0.0
	_apply_frame()


func _apply_frame() -> void:
	_sprite.region_rect = Rect2(
		Vector2(_frame * FRAME_SIZE.x, 0),
		Vector2(FRAME_SIZE.x, FRAME_SIZE.y)
	)


func _animation_texture(unit_id_: String, animation_name: String) -> Texture2D:
	var path := animation_path(unit_id_, animation_name)
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _draw() -> void:
	if max_hp <= 0:
		return
	var pip := 5.0
	var total := max_hp * (pip + 1.0)
	var start := Vector2(-total / 2.0, -52)
	for i in max_hp:
		var r := Rect2(start + Vector2(i * (pip + 1.0), 0), Vector2(pip, 4))
		var filled := i < hp
		var col: Color
		if team == "mech":
			col = Color(0.35, 0.78, 0.35) if filled else Color(0.15, 0.25, 0.15)
		else:
			col = Color(0.85, 0.3, 0.25) if filled else Color(0.3, 0.12, 0.1)
		draw_rect(r, col)
