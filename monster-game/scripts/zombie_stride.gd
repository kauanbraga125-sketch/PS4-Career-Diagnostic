class_name HordeZombieStride
extends RefCounted
const DISTANCE_PER_CYCLE = 280.0
const FRAME_COUNT = 16
var texture: Texture2D
var textures: Dictionary = {}
var frames: Array = []

func _init() -> void :
	var layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/zombie-run-drawn-v78.json"))
	for name in layout.sheets:
		textures[name] = load("res://assets/art/" + str(layout.sheets[name])) as Texture2D
	texture = textures.whole
	for entry in layout.frames: frames.append(read_frame(entry))

func read_frame(entry: Dictionary) -> Dictionary:
	var sheet: Texture2D = textures[entry.sheet]
	var rect = entry.region
	var size = Vector2(rect[2], rect[3])
	var origin = Vector2(rect[0], rect[1])
	var anchor = Vector2(entry.anchor[0], entry.anchor[1])
	var outline = PackedVector2Array(); var uvs = PackedVector2Array()
	for point in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		outline.append(point - anchor);uvs.append((origin + point) / sheet.get_size())
	var result = {"texture": sheet, "outline": outline, "uvs": uvs, "height": float(entry.height), "start": float(entry.start)}
	if entry.has("eye_patch"): result["eye_mesh"] = patch_mesh(entry.eye_patch, textures.expression.get_size())
	if entry.has("mouth_patch"): result["mouth_mesh"] = patch_mesh(entry.mouth_patch, textures.mouth.get_size())
	return result

func patch_mesh(patch: Dictionary, atlas_size: Vector2) -> ArrayMesh:
	var offset = Vector2(patch.offset[0], patch.offset[1])
	var size = Vector2(patch.size[0], patch.size[1])
	var source = Rect2(patch.source_region[0], patch.source_region[1], patch.source_region[2], patch.source_region[3])
	var feather = float(patch.get("feather", 3.0))
	var margin = Vector2(feather / size.x, feather / size.y)
	var points = [Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1), margin, Vector2(1 - margin.x, margin.y), Vector2.ONE - margin, Vector2(margin.x, 1 - margin.y)]
	var vertices = PackedVector3Array(); var uv = PackedVector2Array(); var colors = PackedColorArray()
	for i in range(points.size()):
		var point: Vector2 = points[i]
		var local = offset + point * size
		vertices.append(Vector3(local.x, local.y, 0))
		uv.append((source.position + point * source.size) / atlas_size)
		colors.append(Color(1, 1, 1, 0 if i < 4 else 1))
	var arrays = [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices;arrays[Mesh.ARRAY_TEX_UV] = uv;arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7])
	var mesh = ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func frame_index(phase: float) -> int:
	return posmod(int(fposmod(phase, 1.0) * FRAME_COUNT), FRAME_COUNT)

static func cycle_rate(speed: float) -> float:
	return clampf(speed / DISTANCE_PER_CYCLE, 1.0, 1.65)

func paint(canvas: Node2D, foot: Vector2, height: float, phase: float, tint: Color, reverse: bool, time: float = 0.0) -> void :
	var index = frame_index(phase)
	var frame = frames[index]
	var blink = fposmod(time, 5.4)
	var glance = fposmod(time, 7.2)
	var blinking = index % 8 < 4 and blink >= 0.65 and blink < 0.99
	var glancing = index % 8 >= 4 and glance >= 1.8 and glance < 2.19
	var step = fposmod(phase * 2.0, 1.0)
	var lift = 2.6 * pow(sin((step - 0.76) / 0.24 * PI), 2) if step > 0.76 else 0.0


	var angle = 0.006 * sin((phase * 2.0 - 0.1) * TAU) * (-1 if reverse else 1)
	canvas.draw_set_transform(foot - Vector2(0, lift * height / 112.0), angle, Vector2(-1 if reverse else 1, 1) * height / frame.height)
	canvas.draw_polygon(frame.outline, PackedColorArray([tint]), frame.uvs, frame.texture)
	if (blinking or glancing) and frame.has("eye_mesh"):
		canvas.draw_mesh(frame.eye_mesh, textures.expression, Transform2D.IDENTITY, tint)
	if glancing and frame.has("mouth_mesh"):
		canvas.draw_mesh(frame.mouth_mesh, textures.mouth, Transform2D.IDENTITY, tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
