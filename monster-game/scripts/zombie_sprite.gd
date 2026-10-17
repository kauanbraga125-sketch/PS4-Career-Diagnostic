class_name HordeZombieSprite
extends RefCounted



var sheets: Dictionary = {}
var frames: Array = []
var portrait: AtlasTexture
var stride_run: HordeZombieStride
const IDLE_COUNT = 24
const RUN_FIRST = 24
const RUN_COUNT = 24
const HOVER = [52, 53, 54, 55, 54, 53]

func _init() -> void :
	stride_run = HordeZombieStride.new()
	var layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/zombie-fluid-v73.json"))
	for key in layout.sheets:
		sheets[key] = load("res://assets/art/" + str(layout.sheets[key])) as Texture2D
	for entry in layout.frames:
		var rect = entry.region
		var texture: Texture2D = sheets[entry.sheet]
		var anchor = Vector2(entry.anchor[0], entry.anchor[1])
		var outline = PackedVector2Array()
		var uvs = PackedVector2Array()
		for point in entry.outline:
			var local = Vector2(point[0], point[1])
			outline.append(local - anchor)
			uvs.append((local + Vector2(rect[0], rect[1])) / texture.get_size())
		frames.append({"texture": texture, "outline": outline, "uvs": uvs, "height": float(entry.height)})
	portrait = HordeArt.atlas(sheets[layout.portrait_sheet], layout.portrait)

static func frame_index(state: String, phase: float, time: float, landing: float = 0, air_age: float = -1, vertical_speed: float = 0) -> int:
	match state:
		"idle", "aim": return posmod(int(time * 10), IDLE_COUNT)
		"push": return 64 + posmod(int(time * 14), 8)
		"capture": return 72 + clampi(int(phase * 8), 0, 7)
		"rise":
			if air_age >= 0 and air_age < 0.14: return 48 + clampi(int(air_age / 0.14 * 4), 0, 3)
			return HOVER[posmod(int(time * 10), HOVER.size())]
		"fly": return HOVER[posmod(int(time * 10), HOVER.size())]
		"fall": return 56 + clampi(int(maxf(0, vertical_speed) / 150.0), 0, 3)
		_:
			if landing > 0: return 60 + clampi(int((0.2 - landing) / 0.2 * 4), 0, 3)
			return RUN_FIRST + posmod(int(fposmod(phase, 1.0) * RUN_COUNT), RUN_COUNT)

func paint(canvas: Node2D, foot: Vector2, height: float, phase: float, state: String, time: float, landing: float, tint: Color, reverse: bool, air_age: float = -1, vertical_speed: float = 0) -> void :
	if state == "run" and landing <= 0:
		stride_run.paint(canvas, foot, height, phase, tint, reverse, time)
		return
	var frame = frames[frame_index(state, phase, time, landing, air_age, vertical_speed)]
	var scale = height / float(frame.height)
	var stretch = Vector2.ONE
	var angle = 0.0
	var origin = foot
	if state in ["idle", "aim"]:

		var breath = sin(time * TAU / 2.4)
		stretch = Vector2(1.0 - breath * 0.004, 1.0 + breath * 0.009)
		angle = sin(time * TAU / 4.8) * 0.004
	canvas.draw_set_transform(origin, angle * (-1 if reverse else 1), Vector2(-1 if reverse else 1, 1) * stretch * scale)
	canvas.draw_polygon(frame.outline, PackedColorArray([tint]), frame.uvs, frame.texture)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
