class_name HordeViews
extends RefCounted

var selected = 0
var jar = HordeSoulJar.new()

func heading(g, title: String, subtitle: String = "") -> void :
	g.home_menu.label(g, title, Vector2(68, 96), 43, g.GOLD, false, 900, true, 4)
	if not subtitle.is_empty(): g.home_menu.label(g, subtitle, Vector2(70, 135), 20, g.MINT, false, 1040)

func card(g, rect: Rect2, active: bool = false) -> void :
	g.home_menu.slab(g, rect, Color("30213f"), g.MINT if active else Color("806583"), 14, 5)

	g.paint_target.draw_line(rect.position + Vector2(9, 22), rect.position + Vector2(20, 32), Color("513456"), 2, true)
	g.paint_target.draw_line(rect.end - Vector2(26, 8), rect.end - Vector2(17, 20), Color("513456"), 2, true)

func mission_icon(g, mission: Dictionary, point: Vector2, height: float) -> void :
	if mission.stat == "boost": g.gameplay_ui.running_icon(g, point, height)
	elif mission.stat == "cars": g.scenery.sprite(g, g.art.vehicle("car"), point, height * 0.75)
	elif mission.stat in ["clean_jumps", "jumps", "distance"]: g.item_sprite(4, point, height)
	elif mission.stat in ["bonuses", "flights"]: g.item_sprite(0, point, height)
	elif mission.stat in ["souls", "recruits"]: g.animated_soul(point, height, g.ui_time)
	else: g.item_sprite(1, point, height)

func missions(g) -> void:
	g.pages.missions(g)

func pause(g) -> void :
	g.gameplay_ui.pause(g)

func results(g) -> void :
	g.draw_rect(g.full_rect(), Color(0.025, 0.012, 0.055, 0.84))
	heading(g, "FIM DA HORDA", "A horda caiu. As almas permanecem.")
	g.currency()
	card(g, Rect2(68, 175, 526, 431))
	g.home_menu.label(g, "RESERVA DE ALMAS", Vector2(331, 210), 22, g.GOLD)
	var animated = g.animated_result_souls()
	var view = HordeProgress.board(int(g.run_report.get("old_level", g.data.player_level)), int(g.run_report.get("old_progress", g.data.level_souls)), animated)
	var fill = float(view.progress) / float(view.target)

	if g.result_full_flash > 0: fill = 1.0
	jar.paint(g, Rect2(211, 221, 240, 300), fill, g.ui_time)
	for i in range(mini(5, maxi(1, int(fill * 7))) if fill > 0 else 0):
		var y = lerpf(456, 343, float(i + 1) / 6.0) + sin(g.ui_time * 2 + i) * 6
		g.animated_soul(Vector2(319 + sin(i * 2.3 + g.ui_time * 0.4) * 47, y), 29, g.ui_time + i)
	g.home_menu.label(g, "+" + str(animated) + " ALMAS DESTA FUGA", Vector2(331, 536), 23, g.GOLD, true, 470)
	g.home_menu.label(g, "NÍVEL " + str(view.level), Vector2(91, 570), 20, g.CREAM, false)
	g.home_menu.label(g, str(view.progress) + " / " + str(view.target), Vector2(562, 570), 20, g.MINT, true)
	g.progress_bar(Rect2(91, 583, 480, 10), fill, g.MINT)
	var stats = [{"label": "ALMAS", "value": str(g.runner.souls), "note": "RECORDE: " + str(g.data.best_souls), "icon": 0}, 
		{"label": "DISTÂNCIA", "value": str(g.runner.distance()) + " m", "note": "RECORDE: " + str(g.data.best) + " m", "icon": -1}, 
		{"label": "MOEDAS", "value": "+" + str(g.runner.coins), "note": "GANHAS NESTA FUGA", "icon": 1}, 
		{"label": "VEÍCULOS VIRADOS", "value": str(g.runner.cars), "note": "A HORDA DEIXOU SUA MARCA", "icon": 7}]
	for i in range(4):
		var rect = Rect2(620 + (i % 2) * 302, 175 + (i / 2) * 166, 288, 153)
		card(g, rect)
		g.home_menu.label(g, stats[i].label, rect.position + Vector2(20, 31), 18, g.MINT, false, 248)
		g.home_menu.label(g, stats[i].value, rect.position + Vector2(23, 88), 39, g.GOLD, false, 204)
		g.home_menu.label(g, stats[i].note, rect.position + Vector2(20, 124), 14, g.CREAM, false, 252)
		if stats[i].icon == 0: g.animated_soul(rect.position + Vector2(239, 73), 48, g.ui_time)
		elif stats[i].icon >= 0: g.item_sprite(stats[i].icon, rect.position + Vector2(239, 73), 44)
	var points = 0
	for item in g.data.ritual_pending: points += int(item.points)
	card(g, Rect2(620, 513, 590, 93))
	g.animated_soul(Vector2(660, 557), 47, g.ui_time)
	g.home_menu.label(g, "+" + str(points) + " PONTOS PARA O RITUAL", Vector2(706, 552), 22, g.MINT, false, 470)
	if animated >= g.runner.souls and int(g.run_report.get("levels", 0)) > 0: g.home_menu.label(g, "+" + str(g.run_report.coins) + " MOEDAS DA SORTE", Vector2(706, 583), 19, g.GOLD, false, 470)
	else: g.home_menu.label(g, "Cada alma alimenta a próxima ascensão.", Vector2(706, 583), 17, g.CREAM, false, 470)
	g.button(Rect2(68, 639, 248, 59), "MENU", "home", Color("58416d"), -2, 24)
	g.button(Rect2(337, 639, 344, 59), "MELHORIAS", "shop", Color("715090"), -2, 24)
	g.button(Rect2(705, 632, 505, 66), "▶  DE NOVO", "play", Color("c58a35"), -2, 29)

func collection(g) -> void:
	g.pages.collection(g)
