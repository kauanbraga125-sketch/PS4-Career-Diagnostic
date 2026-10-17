class_name HordeMenuZombie
extends RefCounted

const ANCHOR = Vector2(256, 488)
const HEIGHT = 458.0
const CYCLE = 32.0
const BLEND = preload("res://scripts/menu_zombie_smooth.gdshader")
var atlas: Texture2D = preload("res://assets/art/menu-zombie-base.png")
var data: Dictionary
var pages: Array[Texture2D] = []
var sprites: Array[Sprite2D] = []
var materials: Array[ShaderMaterial] = []
var face: AtlasTexture
var events = [
	{"start": 4.9, "end": 8.9, "enter": 0.95, "exit": 1.3, "lean": -1.7, "tilt": -1.15},
	{"start": 9.9, "end": 13.9, "enter": 0.95, "exit": 1.3, "lean": 2.0, "tilt": 0.9},
	{"start": 14.8, "end": 19.2, "enter": 1.2, "exit": 1.45, "lean": 0.7, "tilt": -1.7},
	{"start": 20.8, "end": 25.4, "enter": 1.15, "exit": 1.6, "lean": 3.0, "tilt": 1.65}
]

func _init() -> void :
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/menu-zombie-animation.json"))
	for page in data.atlases:
		pages.append(load("res://assets/art/" + str(page.file)))
	face = AtlasTexture.new()
	face.atlas = atlas
	face.region = Rect2(90, 25, 340, 255)

func attach(parent: Node2D) -> void :
	for i in range(7):
		var sprite = Sprite2D.new()
		sprite.name = "MenuZombie" + str(i)
		sprite.texture = atlas
		sprite.region_rect = Rect2(0, 0, 512, 512)
		sprite.centered = false
		sprite.offset = - ANCHOR
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.visible = false
		sprite.z_index = 1
		var material = ShaderMaterial.new()
		material.shader = BLEND
		material.set_shader_parameter("body_texture", atlas)
		sprite.material = material
		parent.add_child(sprite)
		sprites.append(sprite)
		materials.append(material)

func set_visible(value: bool) -> void :
	if not value:
		for sprite in sprites: sprite.visible = false

func begin_frame() -> void :
	for sprite in sprites: sprite.visible = false

func ease_quintic(value: float) -> float:
	var t = clampf(value, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)

func envelope(time: float, event: Dictionary) -> float:
	if time < float(event.start) or time >= float(event.end): return 0
	return minf(ease_quintic((time - float(event.start)) / float(event.enter)), ease_quintic((float(event.end) - time) / float(event.exit)))

func state(time: float) -> Dictionary:
	var t = fposmod(time, CYCLE)
	var lean = 0.0
	var tilt = 0.0
	for event in events:
		var head = 0.8 * envelope(t - 0.12, event) + 0.2 * envelope(t - 0.26, event)
		lean += float(event.lean) * head
		tilt += float(event.tilt) * head
	var wave = pow(sin(t * TAU / 8.0), 3)
	var frame = t * float(data.fps)
	var a = int(data.frames[int(floor(frame)) % data.frames.size()])
	var b = int(data.frames[(int(floor(frame)) + 1) % data.frames.size()])
	return {"a": a, "b": b, "mix": 0.0 if a == b else fposmod(frame, 1.0),
		"translation": Vector2(1.7 * wave + lean, 1.25 * (cos(t * TAU / 4.0) - 1.0)),
		"angle": deg_to_rad(0.36 * wave + tilt)}

func paint(index: int, foot: Vector2, height: float, time: float) -> void :
	if index >= sprites.size(): return
	var s = state(time)
	var sprite = sprites[index]
	sprite.visible = true
	sprite.position = foot
	sprite.scale = Vector2.ONE * (height / HEIGHT)
	var mat = materials[index]
	for key in ["a", "b"]:
		var id = int(s[key])
		var page = int(id / int(data.perPage))
		var slot = id % int(data.perPage)
		mat.set_shader_parameter("face_" + key, pages[page])
		mat.set_shader_parameter("face_origin_" + key, Vector2((slot % int(data.columns)) * int(data.tile) + int(data.gutter), int(slot / int(data.columns)) * int(data.tile) + int(data.gutter)))
	mat.set_shader_parameter("face_blend", float(s.mix))
	mat.set_shader_parameter("body_translation", s.translation)
	mat.set_shader_parameter("head_angle", float(s.angle))
