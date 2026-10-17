class_name HordePages
extends RefCounted

func layout(view: Rect2) -> Dictionary:
	var margin = maxf(28, view.size.x * 0.055)
	var left = view.position.x + margin
	var right = view.end.x - margin
	var footer_y = view.end.y - 85
	var top = view.position.y + 172
	var available = footer_y - 22 - top
	var height = minf(560, available)
	top += maxf(0, (available - height) * 0.4)
	var body = Rect2(left, top, right - left, height)
	var cards: Array[Rect2] = []
	for i in range(3): cards.append(Rect2(left + i * (body.size.x + 16) / 3, top, (body.size.x - 32) / 3, height))
	return {"view": view, "body": body, "cards": cards, "back": Rect2(left, footer_y, 244, 64),
		"play": Rect2(right - 300, footer_y - 3, 300, 70), "wallet": Rect2(right - 204, view.position.y + 34, 204, 68),
		"footer": Rect2(left + 265, footer_y, right - left - 590, 64)}

func collection_layout(view: Rect2) -> Dictionary:
	var d = layout(view)
	var b: Rect2 = d.body
	var left = clampf(b.size.x * 0.23, 250, 320)
	var right = clampf(b.size.x * 0.31, 330, 440)
	d.roster = Rect2(b.position, Vector2(left, b.size.y))
	d.powers = Rect2(b.end.x - right, b.position.y, right, b.size.y)
	d.preview = Rect2(b.position.x + left + 22, b.position.y, b.size.x - left - right - 44, b.size.y)
	var roster_rows: Array[Rect2] = []
	var power_rows: Array[Rect2] = []
	for i in range(2):
		var y = b.position.y + 55 + i * (b.size.y - 55 + 14) / 2
		var h = (b.size.y - 69) / 2
		roster_rows.append(Rect2(b.position.x, y, left, h))
		power_rows.append(Rect2(b.end.x - right, y, right, h))
	d.roster_rows = roster_rows;d.power_rows = power_rows
	d.market = Rect2(d.play.position - Vector2(34, 0), d.play.size + Vector2(34, 0))
	return d

func framed(g, rect: Rect2, mode: String = "normal") -> void:
	g.paint_target.draw_style_box(g.home_menu.panel_style, rect)
	if mode != "normal":
		var points = g.home_menu.shape(rect.grow(-3), 15)
		points.append(points[0])
		g.draw_polyline(points, g.MINT if mode == "done" else g.GOLD, 2, true)

func lines(g, value: String, rect: Rect2, size: int, color: Color, center: bool = true, maximum: int = 2) -> void:
	var rows: Array[String] = []
	while size >= 14:
		rows.clear();var row = ""
		for word in value.split(" "):
			var next = word if row.is_empty() else row + " " + word
			if g.home_menu.label_font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x and not row.is_empty(): rows.append(row);row = word
			else: row = next
		if not row.is_empty(): rows.append(row)
		if rows.size() <= maximum and rows.size() * (size + 3) <= rect.size.y: break
		size -= 1
	var y = rect.get_center().y - rows.size() * (size + 3) * 0.5 + size
	for row in rows:
		g.home_menu.label(g, row, Vector2(rect.get_center().x if center else rect.position.x, y), size, color, center, rect.size.x)
		y += size + 3

func header(g, d: Dictionary, title: String, subtitle: String, wallet: bool = true) -> void:
	var width = minf(d.view.size.x * (0.60 if title.begins_with("MISSÕES") else 0.49), 880)
	var rect = Rect2(d.body.position.x - 10, d.view.position.y + 18, width, 105)
	g.draw_texture_rect(g.home_menu.panel_texture, rect, false)
	g.home_menu.label(g, title, rect.get_center() + Vector2(0, 17), 42, g.GOLD, true, width - 95, true, 4)
	g.home_menu.label(g, subtitle, Vector2(d.body.position.x + 8, d.view.position.y + 151), 20, g.MINT, false, d.body.size.x - (260 if wallet else 0))
	if wallet:
		var box: Rect2 = d.wallet
		g.home_menu.slab(g, box, Color("24162f"), Color("c19659"), 12, 3)
		g.scenery.sprite(g, g.art.items[1], box.position + Vector2(35, 34), 40)
		g.home_menu.label(g, str(g.data.wallet), box.position + Vector2(67, 46), 33, g.GOLD, false, box.size.x - 78)

func button(g, rect: Rect2, title: String, action: String, primary: bool = false, icon: String = "") -> void:
	var face = rect
	if g.pressed_button == action: face.position.y += 3
	g.draw_texture_rect(g.home_menu.play_texture if primary else g.home_menu.panel_texture, face, false)
	var point = Vector2(face.position.x + 33, face.get_center().y)
	if icon == "back":
		g.draw_colored_polygon(PackedVector2Array([point + Vector2(9, -13), point + Vector2(-9, 0), point + Vector2(9, 13)]), g.CREAM)
	elif icon == "market": g.scenery.sprite(g, g.art.ritual[2], point + Vector2(3, 0), 37)
	elif not icon.is_empty(): g.gameplay_ui.glyph(g, icon, point, 30, g.CREAM)
	g.home_menu.label(g, title, face.get_center() + Vector2(12 if not icon.is_empty() else 0, 10), 27 if primary else 25, g.CREAM, true, face.size.x - (82 if not icon.is_empty() else 40))
	g.home_menu.register(g, rect, action)

func done_count(data: Dictionary) -> int:
	var count = 0
	for mission in MonsterCatalog.active_missions(int(data.mission_tier)):
		if mission.key in data.claimed: count += 1
	return count

func missions(g) -> void:
	var d = layout(g.full_rect())
	header(g, d, "MISSÕES DA MADRUGADA", "CAPÍTULO " + str(int(g.data.mission_tier) + 1) + "  •  " + str(done_count(g.data)) + " / 3 CONCLUÍDAS")
	var missions = MonsterCatalog.active_missions(int(g.data.mission_tier))
	for i in range(3):
		var m: Dictionary = missions[i]
		var r: Rect2 = d.cards[i]
		var count = clampi(int(g.data.mission_progress.get(m.id, 0)), 0, int(m.target))
		var done = m.key in g.data.claimed
		framed(g, r, "done" if done else "active")
		g.views.mission_icon(g, m, Vector2(r.get_center().x, r.position.y + r.size.y * 0.24), clampf(r.size.y * 0.3, 120, 172))
		if done:
			g.draw_circle(Vector2(r.end.x - 35, r.position.y + 34), 17, g.MINT)
			g.gameplay_ui.glyph(g, "check", Vector2(r.end.x - 35, r.position.y + 34), 24, Color("20352f"))
		else:
			g.home_menu.label(g, "EM ANDAMENTO", Vector2(r.end.x - 88, r.position.y + 35), 14, g.GOLD, true, 136)
		lines(g, m.title, Rect2(r.position.x + 22, r.position.y + r.size.y * 0.40, r.size.x - 44, 65), 27, g.GOLD)
		var remaining = int(m.target) - count
		var status = "CONCLUÍDA" if done else ("FALTA " if remaining == 1 else "FALTAM ") + str(remaining) + (" M" if m.stat in ["distance", "boost"] else "")
		g.home_menu.label(g, status, Vector2(r.get_center().x, r.position.y + r.size.y * 0.63), 25, g.MINT if done else g.CREAM, true, r.size.x - 44)
		var bar = Rect2(r.position.x + 29, r.position.y + r.size.y * 0.70, r.size.x - 58, 14)
		g.progress_bar(bar, float(count) / float(m.target), g.MINT if done else g.GOLD)
		g.home_menu.label(g, str(count) + " / " + str(m.target) + (" m" if m.stat in ["distance", "boost"] else ""), Vector2(r.get_center().x, bar.position.y + 39), 22, g.CREAM)
		var reward = Rect2(r.position.x + 30, r.end.y - 77, r.size.x - 60, 56)
		g.home_menu.slab(g, reward, Color("21172e"), Color("876454"), 10, 2)
		g.animated_soul(reward.get_center() - Vector2(39, 0), 42, g.ui_time + i)
		g.home_menu.label(g, "+" + str(m.ritual), reward.get_center() + Vector2(9, 10), 29, g.MINT)
	button(g, d.back, "VOLTAR", "back", false, "back")
	button(g, d.play, "JOGAR", "play", true, "play")
	lines(g, "RECOMPENSAS DO RITUAL", d.footer, 19, g.GOLD)

func lock(g, point: Vector2, color: Color) -> void:
	g.draw_arc(point + Vector2(0, -4), 5, PI, TAU, 16, color, 2.4, true)
	g.draw_rect(Rect2(point - Vector2(8, 4), Vector2(16, 13)), color)
	g.draw_circle(point + Vector2(0, 2), 1.8, Color("302039"))

func collection(g) -> void:
	var d = collection_layout(g.full_rect())
	var count = int(0 in g.data.owned) + int(1 in g.data.owned)
	header(g, d, "COLEÇÃO DA HORDA", str(count) + " / 2 MONSTROS DESBLOQUEADOS")
	g.views.selected = clampi(g.views.selected, 0, 1)
	for column in [d.roster, d.powers]:
		g.draw_texture_rect(g.home_menu.panel_texture, Rect2(column.position, Vector2(column.size.x, 43)), false)
		g.home_menu.label(g, "MONSTROS" if column == d.roster else "PODERES TEMPORÁRIOS", column.position + Vector2(column.size.x * 0.5, 29), 23, g.GOLD, true, column.size.x - 28)
	for i in range(2):
		var r: Rect2 = d.roster_rows[i]
		var owned = i in g.data.owned
		framed(g, r, "active" if g.views.selected == i else "normal")
		g.scenery.sprite(g, g.home_menu.menu_zombie.face if i == 0 else g.art.rigs[1][0], r.position + Vector2(62, r.size.y * 0.46), 79)
		g.home_menu.label(g, MonsterCatalog.MONSTERS[i].name.to_upper(), r.position + Vector2(121, r.size.y * 0.40), 25, g.GOLD, false, r.size.x - 140)
		var point = r.position + Vector2(127, r.size.y * 0.65)
		if owned: g.gameplay_ui.glyph(g, "check", point, 18, g.MINT)
		else: lock(g, point, g.CORAL)
		g.home_menu.label(g, "LIBERADO" if owned else "BLOQUEADO", point + Vector2(19, 6), 16, g.MINT if owned else g.CORAL, false, r.size.x - 157)
		g.home_menu.register(g, r, "collection_select_" + str(i))
	var preview: Rect2 = d.preview
	var foot = Vector2(preview.get_center().x, preview.end.y - 64)
	var height = minf(400, preview.size.y - 64)
	g.draw_set_transform(foot, 0, Vector2(88, 10));g.draw_circle(Vector2.ZERO, 1, Color(0.02, 0.01, 0.05, 0.45));g.draw_set_transform(Vector2.ZERO)
	if g.views.selected == 0:
		g.home_menu.menu_zombie.begin_frame();g.home_menu.menu_zombie.paint(0, foot, height, g.ui_time)
	else:
		g.home_menu.menu_zombie.set_visible(false)
		g.actor.paint(g, 1, foot, height, g.ui_time * 0.55, "idle", g.ui_time, 0, Color.WHITE, false, 1, false)
	g.home_menu.label(g, MonsterCatalog.MONSTERS[g.views.selected].name.to_upper(), foot + Vector2(0, 35), 30, g.GOLD, true, preview.size.x)
	var unlocked = g.views.selected in g.data.owned
	g.home_menu.label(g, "LIBERADO" if unlocked else "BLOQUEADO", foot + Vector2(0, 66), 18, g.MINT if unlocked else g.CORAL)
	for i in range(2):
		var kind = 3 if i == 0 else 2
		var r: Rect2 = d.power_rows[i]
		var owned = kind in g.data.power_owned
		framed(g, r)
		g.scenery.sprite(g, g.art.power(kind, g.ui_time), r.position + Vector2(59, r.size.y * 0.43), 84)
		g.home_menu.label(g, "SUPER FLY" if kind == 3 else "MASCARADO", r.position + Vector2(117, 39), 26, g.GOLD, false, r.size.x - 138)
		lines(g, "Voe sobre os perigos." if kind == 3 else "Força para abrir caminho.", Rect2(r.position.x + 117, r.position.y + 48, r.size.x - 138, 52), 18, g.MINT, false)
		var point = r.position + Vector2(126, r.size.y - 36)
		if owned: g.gameplay_ui.glyph(g, "check", point, 18, g.MINT)
		else: lock(g, point, g.CREAM)
		var tag = Rect2(r.end.x - 116, r.end.y - 48, 96, 25)
		g.home_menu.slab(g, tag, Color("281d36"), Color("665271"), 6, 1)
		g.home_menu.label(g, "TEMPORÁRIO", tag.get_center() + Vector2(0, 5), 13, Color("cbbbd1"), true, 84)
		g.home_menu.label(g, "LIBERADO" if owned else "NO MERCADO", point + Vector2(21, 7), 19, g.MINT if owned else g.CREAM, false, tag.position.x - point.x - 30)
		g.home_menu.register(g, r, "powers")
	button(g, d.back, "VOLTAR", "back", false, "back")
	button(g, d.market, "VER NO MERCADO", "market_monsters", true, "market")
	lines(g, "Capture civis e aumente a horda." if g.views.selected == 0 else "Pode surgir ao capturar civis.", d.footer, 18, g.MINT)

func help(g) -> void:
	var d = layout(g.full_rect())
	header(g, d, "COMO JOGAR", "APRENDA OS CONTROLES E PREPARE A HORDA", false)
	var titles = ["1. PULE E CAPTURE", "2. VIRE VEÍCULOS", "3. USE OS PODERES"]
	for i in range(3):
		framed(g, d.cards[i])
		g.home_menu.label(g, titles[i], d.cards[i].position + Vector2(d.cards[i].size.x * 0.5, 39), 27, g.GOLD, true, d.cards[i].size.x - 34)
	var r: Rect2 = d.cards[0]
	g.home_menu.label(g, "Cada civil rende uma alma.", r.position + Vector2(r.size.x * 0.5, 67), 18, g.MINT, true, r.size.x - 40)
	var floor_y = r.position.y + r.size.y * 0.46
	g.actor.paint(g, 0, Vector2(r.get_center().x - 60, floor_y), 115, g.ui_time * 0.8, "rise", g.ui_time, 0, Color.WHITE, false, 1, false, 0.25, -220)
	g.actor.paint(g, 4, Vector2(r.get_center().x + 68, floor_y + 5), 114, g.ui_time * 0.7, "panic_run", g.ui_time, 0, Color.WHITE, false, 1, false)
	g.animated_soul(Vector2(r.get_center().x + 4, floor_y - 88), 39, g.ui_time)
	g.home_menu.label(g, "+1", Vector2(r.get_center().x + 32, floor_y - 78), 27, g.MINT)
	var y = r.position.y + r.size.y * 0.55
	for i in range(2):
		var box = Rect2(r.position.x + 16 + i * (r.size.x - 20) / 2, y, (r.size.x - 44) / 2, r.size.y * 0.23)
		g.home_menu.slab(g, box, Color("2b1b39"), Color("896949"), 9, 2)
		g.item_sprite(4, box.position + Vector2(27, box.size.y * 0.47), 39)
		lines(g, "TOQUE PARA PULAR" if i == 0 else "SEGURE PARA IR MAIS ALTO", Rect2(box.position.x + 52, box.position.y + 7, box.size.x - 60, box.size.y - 14), 18, g.CREAM, true, 3)
	lines(g, "SALTO DUPLO: MELHORIA NÍVEL 2", Rect2(r.position.x + 17, r.end.y - 59, r.size.x - 34, 44), 18, g.MINT)
	r = d.cards[1]
	g.home_menu.label(g, "Junte a força necessária.", r.position + Vector2(r.size.x * 0.5, 67), 18, g.MINT)
	var vehicle_point = Vector2(r.get_center().x + 25, r.position.y + r.size.y * 0.36)
	g.scenery.sprite(g, g.art.vehicle("car"), vehicle_point, 81)
	for i in range(3): g.actor.paint(g, 0, vehicle_point + Vector2(-100 - i * 26, 41 - i % 2 * 6), 80, g.ui_time * 0.7 + i * 0.2, "push", g.ui_time, 0, Color.WHITE, false, 1, false)
	lines(g, "Pule quando a força não bastar.", Rect2(r.position.x + 15, r.position.y + r.size.y * 0.47, r.size.x - 30, 40), 17, g.MINT)
	var kinds = ["moto", "car", "bus", "truck", "tank", "plane"]
	var grid = Rect2(r.position.x + 16, r.position.y + r.size.y * 0.58, r.size.x - 32, r.size.y * 0.42 - 19)
	for i in range(6):
		var size = Vector2((grid.size.x - 12) / 3, (grid.size.y - 7) / 2)
		var box = Rect2(grid.position + Vector2((i % 3) * (size.x + 6), int(i / 3) * (size.y + 7)), size)
		g.home_menu.slab(g, box, Color("261a34"), Color("70516c"), 7, 1)
		g.home_menu.label(g, MonsterCatalog.VEHICLES[kinds[i]].name, box.position + Vector2(size.x * 0.5, 21), 14, g.CREAM, true, size.x - 8)
		g.scenery.sprite(g, g.art.vehicle(kinds[i]), box.get_center() + Vector2(0, 1), maxf(22, size.y - 57))
		g.home_menu.label(g, str(MonsterCatalog.VEHICLES[kinds[i]].need), Vector2(box.get_center().x, box.end.y - 7), 23, g.GOLD)
	r = d.cards[2]
	var names = ["SUPER FLY", "MASCARADO", "FRENESI"]
	var descriptions = ["Solte para subir. Segure para descer.", "Mais força e proteção.", "Velocidade e moedas em dobro."]
	for i in range(3):
		var h = (r.size.y - 93) / 3
		var box = Rect2(r.position.x + 13, r.position.y + 65 + i * (h + 9), r.size.x - 26, h)
		g.home_menu.slab(g, box, Color("281a35"), Color("70516c"), 10, 2)
		var point = box.position + Vector2(38, box.size.y * 0.5)
		if i == 0: g.item_sprite(0, point, 60)
		elif i == 1: g.scenery.sprite(g, g.art.power(2, g.ui_time), point, 59)
		else: g.scenery.sprite(g, g.market.sprites.potion, point, 57)
		g.home_menu.label(g, names[i], box.position + Vector2(78, 29), 22, g.GOLD, false, box.size.x - 148)
		lines(g, descriptions[i], Rect2(box.position.x + 78, box.position.y + 38, box.size.x - 149, box.size.y - 43), 17, g.MINT, false, 3)
		g.actor.paint(g, [3, 2, 0][i], Vector2(box.end.x - 38, box.end.y - 11), minf(75, box.size.y - 15), g.ui_time * 0.7, "fly" if i == 0 else "run", g.ui_time, 0, Color.WHITE, false, 1, false)
	button(g, d.back, "VOLTAR", "back", false, "back")
	button(g, d.play, "JOGAR", "play", true, "play")
	button(g, Rect2(d.back.end.x + 18, d.back.position.y + 8, 156, 49), "CRÉDITOS", "credits")
