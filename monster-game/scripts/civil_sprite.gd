class_name HordeCivilSprite
extends RefCounted

const ROOT = "res://assets/art/civil-azul-v089/"
static var manifest: Dictionary = {}
var frames: Dictionary = {}
var portrait: AtlasTexture

static func metadata() -> Dictionary:
	if manifest.is_empty(): manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "animacoes.json")).animations
	return manifest

static func sample(clip: String, age: float) -> int:
	var spec: Dictionary = metadata()[clip]
	var duration = 0.0
	for value in spec.durations_ms: duration += float(value) / 1000.0
	var at = fposmod(age, duration) if spec.loop else clampf(age, 0, duration - 0.000001)
	for i in range(int(spec.frame_count)):
		at -= float(spec.durations_ms[i]) / 1000.0
		if at < 0: return i
	return int(spec.frame_count) - 1

func _init() -> void:
	for clip in metadata():
		var spec: Dictionary = manifest[clip]
		var sheet = load(ROOT + str(spec.sheet)) as Texture2D
		var regions: Array[AtlasTexture] = []
		for i in range(int(spec.frame_count)):
			regions.append(HordeArt.atlas(sheet, [i % int(spec.columns) * 640, int(i / int(spec.columns)) * 640, 640, 640]))
		frames[clip] = regions
	var idle: AtlasTexture = frames.parado_nervoso[0]
	portrait = HordeArt.atlas(idle.atlas, [180, 38, 340, 292])

func pose(e: Dictionary) -> Array:
	if e.get("state", "normal") == "capture":
		var age = clampf(0.62 - float(e.capture_left), 0, 0.62)
		var bridge = 0.10 if e.get("civil_capture_transition", false) else 0.0
		if age < bridge: return ["transicao_corrida_captura", mini(2, int(age / bridge * 3))]
		if float(e.capture_left) <= 0.08: return ["captura", 11]
		var source_motion = 0.0
		for duration in metadata().captura.durations_ms.slice(0, 11): source_motion += float(duration) / 1000.0
		var source_time = (age - bridge) / (0.62 - bridge - 0.08) * source_motion
		return ["captura", mini(10, sample("captura", source_time))]
	var clip = str(e.get("civil_clip", "parado_nervoso"))
	return [clip, sample(clip, float(e.get("civil_time", 0)))]

func paint(canvas: Node2D, e: Dictionary, foot: Vector2, height: float = 112.0, tint: Color = Color.WHITE) -> void:
	var selected = pose(e)
	var progress = clampf(1.0 - float(e.get("civil_turn_left", 0)) / 0.09, 0, 1)
	var flipped = bool(e.get("civil_flip", true))
	if progress < 0.5: flipped = bool(e.get("civil_previous_flip", flipped))
	var width = 1.0 - sin(progress * PI) * 0.08
	canvas.draw_set_transform(foot, 0, Vector2((-1.0 if flipped else 1.0) * width, 1) * height / 500.0)
	canvas.draw_texture_rect(frames[selected[0]][selected[1]], Rect2(-320, -560, 640, 640), false, tint)
	canvas.draw_set_transform(Vector2.ZERO)
