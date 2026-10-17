class_name HordeTerrainArt
extends RefCounted

static func cell(texture: Texture2D, index: int) -> Rect2:
	var x1 = roundf(index % 4 * texture.get_width() / 4.0)
	var x2 = roundf((index % 4 + 1) * texture.get_width() / 4.0)
	var y1 = roundf(int(index / 4) * texture.get_height() / 2.0)
	return Rect2(x1, y1, x2 - x1, texture.get_height() / 2.0)

static func pit_edge(g, edge: float, floor_y: float, right_bank: bool) -> void:
	var source = cell(g.art.terrain_parts, 5 if right_bank else 4)
	source.position += Vector2(94 if right_bank else 290, 118);source.size = Vector2(150, 314)
	g.paint_target.draw_texture_rect_region(g.art.terrain_parts, Rect2(edge - (12 if right_bank else 44), floor_y - 1, 55, 115), source)

static func elevation(g, edge: float, floor_y: float, height: float, right_bank: bool) -> void:
	var source = cell(g.art.terrain_parts, 7 if right_bank else 6)
	source.position += Vector2(98 if right_bank else 15, 28);source.size = Vector2(333 if right_bank else 367, 401)
	var width = maxf(58, height * 0.72)
	g.paint_target.draw_texture_rect_region(g.art.terrain_parts, Rect2(edge - width * (0.67 if right_bank else 0.33), floor_y, width, height + 28), source)

static func collapse(g, e: Dictionary) -> void:
	var opened = bool(e.get("collapsed", false))
	var age = maxf(0, float(g.runner.elapsed) - float(e.get("collapse_at", g.runner.elapsed)))
	if opened and age > 1.0: return
	var frame = 3 if opened else (2 if e.get("armed", false) and float(e.get("collapse_left", 1)) < 0.34 else (1 if e.get("armed", false) or int(e.get("fracture_variant", 0)) != 0 else 0))
	var source = cell(g.art.terrain_parts, frame)
	source.position += Vector2(14, 161);source.size = Vector2(418, 270)
	var pieces = ceili(float(e.width) / 108.0)
	var unit = float(e.width) / pieces
	for i in range(pieces):
		var y = float(e.y) + (330 * age * age if opened else (sin(g.runner.elapsed * 47 + i) * 1.5 if e.get("armed", false) else 0.0))
		var angle = sin(float(e.id) + i) * age * 0.55 if opened else 0.0
		g.paint_target.draw_set_transform(Vector2(float(e.x) + unit * (i + 0.5), y), angle)
		g.paint_target.draw_texture_rect_region(g.art.terrain_parts, Rect2(-unit * 0.5, -1, unit + 0.6, 72), source, Color(1, 1, 1, clampf((1.0 - age) / 0.4, 0, 1) if opened else 1.0))
	g.paint_target.draw_set_transform(Vector2.ZERO)
	if not opened and g.runner.tutorial_hints():
		var warning = g.CORAL if e.get("armed", false) else g.GOLD
		g.paint_target.draw_line(Vector2(e.x, e.y - 2), Vector2(e.x + e.width, e.y - 2), warning, 2, true)
		for edge in [e.x, e.x + e.width]:
			g.paint_target.draw_line(Vector2(edge, e.y - 10), Vector2(edge, e.y + 8), warning, 3, true)
		if e.x > HordeRun.ANCHOR: g.text("CHÃO CEDE!", Vector2(e.x + e.width * 0.5, e.y - 26), 16, warning, true, true, 3)
