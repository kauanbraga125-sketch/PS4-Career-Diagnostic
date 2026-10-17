class_name HordeGameplayUI
extends RefCounted

var ground_texture: AtlasTexture

func _init() -> void:
	ground_texture = AtlasTexture.new()
	ground_texture.atlas = preload("res://assets/art/gameplay-ground-v83.png")
	ground_texture.region = Rect2(0, 94, 2172, 552)
	ground_texture.filter_clip = true

func hud_layout(view: Rect2) -> Dictionary:
	var left = view.position.x + 28
	var top = view.position.y + 20
	var widths = [190.0, 168.0, 154.0, 170.0]
	var counters: Array[Rect2] = []
	for width in widths:
		counters.append(Rect2(left, top, width, 78))
		left += width + 12
	var pause_rect = Rect2(view.end.x - 100, top, 72, 76)
	return {"counters": counters, "pause": pause_rect,
		"location": Vector2(view.position.x + 32, top + 107),
		"effect": Rect2(pause_rect.position.x - 332, top, 308, 78)}

func counter_target(g, index: int) -> Vector2:
	var rect: Rect2 = hud_layout(g.full_rect()).counters[index]
	return rect.position + Vector2(39, 52)

func glyph(g, kind: String, point: Vector2, size: float, color: Color) -> void:
	match kind:
		"pause":
			for x in [-0.23, 0.10]:
				g.draw_rect(Rect2(point + Vector2(x * size, -size * 0.35), Vector2(size * 0.15, size * 0.70)), color)
		"play":
			g.draw_colored_polygon(PackedVector2Array([point + Vector2(-0.3, -0.4) * size,
				point + Vector2(0.38, 0) * size, point + Vector2(-0.3, 0.4) * size]), color)
		"retry":
			g.draw_arc(point, size * 0.34, -0.6, 4.7, 28, color, maxf(3, size * 0.11), true)
			g.draw_colored_polygon(PackedVector2Array([point + Vector2(0, -0.53) * size,
				point + Vector2(0.31, -0.31) * size, point + Vector2(-0.04, -0.10) * size]), color)
		"home":
			g.draw_colored_polygon(PackedVector2Array([point + Vector2(-0.48, -0.04) * size,
				point + Vector2(0, -0.48) * size, point + Vector2(0.48, -0.04) * size,
				point + Vector2(0.34, -0.04) * size, point + Vector2(0.34, 0.4) * size,
				point + Vector2(0.10, 0.4) * size, point + Vector2(0.10, 0.09) * size,
				point + Vector2(-0.10, 0.09) * size, point + Vector2(-0.10, 0.4) * size,
				point + Vector2(-0.34, 0.4) * size, point + Vector2(-0.34, -0.04) * size]), color)
		"check":
			g.draw_polyline(PackedVector2Array([point + Vector2(-0.31, -0.01) * size,
				point + Vector2(-0.07, 0.23) * size, point + Vector2(0.35, -0.25) * size]), color, maxf(2.5, size * 0.14), true)
		"distance":
			var origin = point - Vector2(size * 0.30, size * 0.42)
			g.draw_line(origin - Vector2(0, 2), origin + Vector2(-size * 0.06, size * 0.93), color, 2.5, true)
			var cell = size * 0.17
			g.draw_rect(Rect2(origin, Vector2(cell * 4, cell * 3)), color)
			for row in range(3):
				for col in range(4):
					if (row + col) % 2 == 0: g.draw_rect(Rect2(origin + Vector2(col, row) * cell, Vector2.ONE * cell), Color("31203f"))

func hud(g) -> void:
	var d = hud_layout(g.full_rect())
	var labels = ["DISTÂNCIA", "HORDA", "ALMAS", "MOEDAS"]
	var values = [str(g.runner.distance()) + " m", str(g.runner.active_count()), str(g.runner.souls), str(g.runner.coins)]
	for i in range(4):
		var rect: Rect2 = d.counters[i]
		g.home_menu.slab(g, rect, Color("21152e"), Color("bd915b"), 12, 3)
		g.home_menu.label(g, labels[i], rect.position + Vector2(15, 23), 15, g.MINT, false, rect.size.x - 28)
		var centre = rect.position + Vector2(37, 52)
		if i == 0: glyph(g, "distance", centre, 30, g.CREAM)
		elif i == 1: g.scenery.sprite(g, g.actor.zombie.portrait, centre + Vector2(0, sin(g.ui_time * 2.5) * 1.5), 47, Color.WHITE, sin(g.ui_time * 2.5) * 0.045)
		elif i == 2: g.animated_soul(centre, 44, g.ui_time)
		else: g.scenery.sprite(g, g.art.items[1], centre + Vector2(0, sin(g.ui_time * 2) * 1.4), 39 + g.coin_pulse * 3, Color.WHITE, sin(g.ui_time * 1.8) * 0.035)
		var inset = 62 if i == 0 else 69
		g.home_menu.label(g, values[i], rect.position + Vector2(inset, 62), 30, g.GOLD if i >= 2 else g.CREAM, false, rect.size.x - inset - 12)
	var pause_rect: Rect2 = d.pause
	g.home_menu.slab(g, pause_rect, Color("493053"), Color("bd915b"), 12, 4)
	glyph(g, "pause", pause_rect.get_center(), 40, g.CREAM)
	g.home_menu.register(g, pause_rect, "pause")
	g.home_menu.label(g, ("TESTE  •  " + g.LAB_LABELS[g.LAB_KINDS.find(g.lab_kind)] if g.lab_active else MonsterCatalog.AREAS[g.runner.area()].name.to_upper() + "  •  TÚNEL " + str(g.runner.tunnel_number())), d.location, 19, MonsterCatalog.AREAS[g.runner.area()].color, false, 680)
	var effect: Rect2 = d.effect
	if g.runner.perk_left > 0:
		g.home_menu.slab(g, effect, Color("33203f"), Color("a582bd"), 12, 3)
		g.scenery.sprite(g, g.art.power(g.runner.perk_kind, g.ui_time), effect.position + Vector2(35, 41), 51)
		g.home_menu.label(g, "SUPER FLY" if g.runner.perk_kind == 3 else "MASCARADO", effect.position + Vector2(71, 29), 20, g.MINT, false, effect.size.x - 84)
		g.home_menu.label(g, "ESCUDO " + str(g.runner.shields) if g.runner.shields > 0 else "PODER ATIVO", effect.position + Vector2(72, 53), 17, g.CREAM, false, effect.size.x - 84)

	elif g.runner.boost_left > 0:
		g.home_menu.slab(g, effect, Color("483142"), Color("d2a35c"), 12, 3)
		g.scenery.sprite(g, g.actor.zombie.portrait, effect.position + Vector2(35, 41), 48)
		g.home_menu.label(g, "FRENESI", effect.position + Vector2(72, 36), 24, g.GOLD, false, effect.size.x - 84)
		g.home_menu.label(g, "IMPLACÁVEL" if g.runner.boost_protected() else "ACELERAÇÃO", effect.position + Vector2(73, 61), 18, g.CREAM, false)
	if g.runner.inside_tunnel():
		g.home_menu.label(g, "TÚNEL " + str(g.runner.tunnel_number()), Vector2(g.full_rect().get_center().x, d.location.y + 43), 24, g.GOLD)
	for car in g.runner.entities:
		if g.runner.tutorial_hints() and car.kind == "car" and car.rushing and car.warned and not car.taken and car.x > HordeRun.ANCHOR:
			var warn = Rect2(g.full_rect().end.x - 370, d.location.y + 26, 292, 52)
			g.home_menu.slab(g, warn, Color("6c2f39"), g.GOLD, 12, 3)
			g.home_menu.label(g, "CARRO!  PULE!", warn.get_center() + Vector2(0, 10), 26, g.GOLD)
			break

	if g.runner.tutorial_hints() and g.runner.elapsed < 7:
		g.home_menu.slab(g, Rect2(405, g.full_rect().position.y + 107, 711, 74), Color("241a32"), g.GOLD, 12, 2)
		g.wrapped("TOQUE PARA PULAR. SEGURE PARA IR MAIS LONGE. TOQUE DE NOVO AO POUSAR.", Vector2(425, g.full_rect().position.y + 135), 670, 19, g.CREAM, 2)
	elif g.runner.speech_left > 0 and not g.runner.speech_text.is_empty() and g.toast_left <= 0: dialogue(g)
	if g.lab_active:
		g.button(Rect2(g.full_rect().end.x - 226, g.full_rect().end.y - 64, 205, 43), "OCULTAR COLISÕES" if g.lab_hitboxes else "COLISÕES", "lab_hitboxes", Color("513c67"), -2, 17)
		if g.lab_kind == "powers":
			for i in range(4):
				g.button(Rect2(30 + i * 215, g.full_rect().end.y - 64, 202, 43), ["FRENESI", "SUPER FLY", "MASCARADO", "PROTEÇÃO: " + ("SIM" if int(g.runner.levels.get("frenzy", 0)) > 0 else "NÃO")][i], "lab_power_" + ["boost", "fly", "mask", "upgrade"][i], Color("4c786a"), -2, 17)

func pause_layout(view: Rect2) -> Dictionary:
	var size = Vector2(clampf(view.size.x * 0.86, 1120, 1480), clampf(view.size.y * 0.81, 568, 700))
	var frame = Rect2(view.get_center() - size * 0.5, size)
	var body = Rect2(frame.position + Vector2(28, 128), frame.size - Vector2(56, 156))
	var right_width = clampf(body.size.x * 0.30, 302, 405)
	var gap = 14.0
	var row_height = (body.size.y - gap * 2) / 3.0
	var rows: Array[Rect2] = []
	for i in range(3): rows.append(Rect2(body.position + Vector2(0, i * (row_height + gap)), Vector2(body.size.x - right_width - 24, row_height)))
	var x = body.end.x - right_width
	var first = clampf(row_height * 0.82, 92, 112)
	var other = clampf(row_height * 0.70, 78, 94)
	var small = 62.0
	var space = (body.size.y - first - other * 2 - small) / 3.0
	var resume = Rect2(x, body.position.y, right_width, first)
	var retry = Rect2(x, resume.end.y + space, right_width, other)
	var home = Rect2(x, retry.end.y + space, right_width, other)
	var settings = Rect2(x, body.end.y - small, right_width, small)
	return {"frame": frame, "rows": rows, "resume": resume, "retry": retry, "home": home, "settings": settings}

func action_button(g, rect: Rect2, label: String, action: String, kind: String, primary: bool = false) -> void:
	var face = rect
	if g.pressed_button == action: face.position.y += 3
	if primary: g.draw_texture_rect(g.home_menu.play_texture, face, false)
	else: g.home_menu.slab(g, face, Color("533b65"), Color("a781a3"), 13, 5)
	var icon_point = Vector2(face.position.x + 40, face.get_center().y)
	if kind == "settings": g.home_menu.gear(g, icon_point, 15, 0)
	else: glyph(g, kind, icon_point, 34 if primary else 29, g.CREAM)
	var text_size = 28 if primary else (20 if kind == "settings" else 25)
	g.home_menu.label(g, label, face.get_center() + Vector2(16, text_size * 0.35), text_size, g.CREAM, true, face.size.x - 93)
	g.home_menu.register(g, rect, action)

func running_icon(g, point: Vector2, height: float) -> void:
	for i in range(3):
		var at = point + Vector2(-height * 0.42, -height * (0.27 - i * 0.22))
		g.draw_line(at - Vector2(height * (0.20 + i * 0.05), 0), at, g.GOLD * Color(1, 1, 1, 0.8), 3, true)
	g.actor.paint(g, 0, point + Vector2(5, height * 0.50), height, g.ui_time * 0.85, "run", g.ui_time, 0, Color.WHITE, false, 0, false)

func pause(g) -> void:
	g.draw_rect(g.full_rect(), Color(0.025, 0.012, 0.055, 0.64))
	var d = pause_layout(g.full_rect())
	var frame: Rect2 = d.frame
	g.draw_style_box(g.home_menu.panel_style, frame)
	g.home_menu.corners(g, frame.grow(-3), Color("f6c46f"))
	g.home_menu.label(g, "PAUSA", frame.position + Vector2(32, 62), 47, g.GOLD, false, 370, true, 3)
	g.home_menu.label(g, "MISSÕES DA FUGA • CAPÍTULO " + str(int(g.data.mission_tier) + 1), frame.position + Vector2(34, 96), 21, g.MINT, false, frame.size.x - 430)
	var chip_y = frame.position.y + 37
	var souls = Rect2(frame.end.x - 217, chip_y, 183, 48)
	var level = Rect2(souls.position.x - 137, chip_y, 123, 48)
	g.home_menu.slab(g, level, Color("25192f"), Color("8b6c8b"), 10, 2)
	g.home_menu.label(g, "NÍVEL " + str(g.data.player_level), level.get_center() + Vector2(0, 8), 20, g.CREAM, true, level.size.x - 20)
	g.home_menu.slab(g, souls, Color("25192f"), Color("8b6c8b"), 10, 2)
	g.animated_soul(souls.position + Vector2(25, 24), 39, g.ui_time)
	g.home_menu.label(g, str(g.runner.souls) + " ALMAS", souls.position + Vector2(49, 32), 22, g.MINT, false, souls.size.x - 60)
	var missions = MonsterCatalog.active_missions(int(g.data.mission_tier))
	for i in range(3):
		var mission: Dictionary = missions[i]
		var row: Rect2 = d.rows[i]
		var count = mini(int(mission.target), maxi(0, int(g.data.mission_progress.get(mission.id, 0))))
		var done = mission.key in g.data.claimed
		g.views.card(g, row, done)
		var icon_point = Vector2(row.position.x + 53, row.get_center().y)
		if mission.stat == "boost": running_icon(g, icon_point, 76)
		else: g.views.mission_icon(g, mission, icon_point, 74)
		var text_x = row.position.x + 110
		g.home_menu.label(g, mission.title, Vector2(text_x, row.position.y + row.size.y * 0.29), 24, g.GOLD, false, row.size.x - 236)
		var status = "CONCLUÍDA" if done else "FALTAM " + str(maxi(0, int(mission.target) - count)) + (" M" if mission.stat in ["distance", "boost"] else "")
		var status_y = row.position.y + row.size.y * 0.54
		if done:
			g.draw_circle(Vector2(text_x + 10, status_y - 6), 12, g.MINT)
			glyph(g, "check", Vector2(text_x + 10, status_y - 6), 16, Color("24483b"))
		g.home_menu.label(g, status, Vector2(text_x + (30 if done else 0), status_y), 19, g.MINT if done else g.GOLD, false, row.size.x - 245)
		var bar = Rect2(text_x, row.end.y - 28, row.size.x - 325, 12)
		g.progress_bar(bar, float(count) / maxf(1, float(mission.target)), g.MINT if done else g.GOLD)
		g.home_menu.label(g, str(count) + " / " + str(mission.target) + (" m" if mission.stat in ["distance", "boost"] else ""), Vector2(bar.end.x + 12, bar.position.y + 12), 16, g.MINT if done else g.CREAM, false, 90)
		g.animated_soul(Vector2(row.end.x - 100, row.position.y + row.size.y * 0.47), 40, g.ui_time + i)
		g.home_menu.label(g, "+" + str(mission.ritual), Vector2(row.end.x - 75, row.position.y + row.size.y * 0.47 + 9), 25, g.MINT, false, 66)
	action_button(g, d.resume, "CONTINUAR", "resume", "play", true)
	action_button(g, d.retry, "RECOMEÇAR", "retry", "retry")
	action_button(g, d.home, "MENU", "home", "home")
	action_button(g, d.settings, "CONFIGURAÇÕES", "settings", "settings")

func ground(g, offset: float) -> void:
	var left: float = g.scenery.view_left
	var right: float = g.scenery.view_right
	var height = 192.0
	var width = ground_texture.get_width() * height / ground_texture.get_height()
	for segment in g.runner.terrain.segments:
		var start = maxf(left, float(segment.start) - offset)
		var end = minf(right, float(segment.end) - offset)
		if start >= end: continue
		var floor_y = HordeRun.FLOOR - float(segment.height)
		g.paint_target.draw_rect(Rect2(start, floor_y, end - start, g.scenery.view_bottom - floor_y), Color("20172f"))
		for tile in range(floori((start + offset) / width), ceili((end + offset) / width)):
			var tile_x = tile * width - offset
			var x1 = maxf(start, tile_x)
			var x2 = minf(end, tile_x + width)
			var source = ground_texture.region
			source.position.x += (x1 - tile_x) / width * ground_texture.region.size.x
			source.size.x = (x2 - x1) / width * ground_texture.region.size.x
			g.paint_target.draw_texture_rect_region(ground_texture.atlas, Rect2(x1, floor_y, x2 - x1, height), source)
		if float(segment.height) > 0:
			var entry = float(segment.start) - offset
			if g.runner.tutorial_hints() and entry > HordeRun.ANCHOR and entry < right - 30:
				g.text("PULE!", Vector2(entry - 52, HordeRun.FLOOR - 28), 15, g.GOLD, true, true, 2)
			for i in range(2):
				var edge = float(segment.start if i == 0 else segment.end) - offset
				if edge < left or edge > right: continue
				HordeTerrainArt.elevation(g, edge, floor_y, float(segment.height), i == 1)

func dialogue(g) -> void:
	var rect = Rect2(405, g.full_rect().position.y + 107, 711, 74)
	g.home_menu.slab(g, rect, Color("241a32"), Color("b99362"), 12, 2)
	var rig = clampi(int(g.runner.speech_npc), 0, g.art.rigs.size() - 1)
	var portrait = g.art.civil.portrait if rig == 4 else g.art.rigs[rig][0]
	g.paint_target.draw_texture_rect(portrait, Rect2(rect.position + Vector2(8, 8), Vector2(62, 56)), false)
	g.wrapped(g.runner.speech_text, rect.position + Vector2(84, 30), 605, 21, g.CREAM, 2)
