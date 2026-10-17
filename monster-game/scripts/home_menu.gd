class_name HordeHomeMenu
extends RefCounted



const INK = Color("20132f")
const IVORY = Color("fff0cc")
const GOLD = Color("ffc464")
const MINT = Color("8fe7c9")
var logo_font: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
var label_font: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
var menu_zombie = HordeMenuZombie.new()
var logo_texture: Texture2D = preload("res://assets/art/menu-logo-v80.png")
var panel_texture: Texture2D = preload("res://assets/art/menu-panel-v80.png")
var play_texture: Texture2D = preload("res://assets/art/menu-play-v80.png")
var missions_texture: Texture2D = preload("res://assets/art/menu-missions-v80.png")
var background_texture: Texture2D = preload("res://assets/art/menu-background-v81.png")
var panel_style: StyleBoxTexture
var play_style: StyleBoxTexture

func _init() -> void :
	panel_style = framed_style(panel_texture)
	play_style = framed_style(play_texture)

func framed_style(texture: Texture2D) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin(SIDE_LEFT, 42)
	style.set_texture_margin(SIDE_RIGHT, 42)
	style.set_texture_margin(SIDE_TOP, 27)
	style.set_texture_margin(SIDE_BOTTOM, 27)
	return style

func attach(parent: Node2D) -> void :
	menu_zombie.attach(parent)

func set_visible(value: bool) -> void :
	menu_zombie.set_visible(value)

func layout(view: Rect2) -> Dictionary:
	var margin = maxf(30, view.size.x * 0.045)
	var left = view.position.x + margin
	var right = view.end.x - margin
	var top = view.position.y + 25
	var nav = Rect2(left, view.end.y - 112, right - left, 84)
	var right_width = minf(600, view.size.x * 0.37)
	var play = Rect2(right - right_width, nav.position.y - 138, right_width, 112)
	var ritual = Rect2(play.position.x + 12, play.position.y - 96, play.size.x - 24, 80)
	var altar_height = clampf((play.position.y - top - 132) * 0.79, 180, 264)
	var altar = Vector2(play.get_center().x, ritual.position.y + 35 - altar_height * 0.5)
	var stage_bottom = view.position.y + view.size.y * 0.785
	var stage_height = clampf(view.size.y * 0.525, 300, 395)
	var wallet = Rect2(right - 318, top, 170, 65)
	var level_left = view.position.x + view.size.x * 0.34
	var level = Rect2(level_left, top, minf(view.size.x * 0.32, wallet.position.x - level_left - 26), 65)
	var title_width = minf(view.size.x * 0.27, 430)
	var result = {"view": view, "title": Rect2(left - 2, top - 8, title_width, title_width * 0.49),
		"level": level, "wallet": wallet, "audio": Rect2(right - 136, top, 62, 65), "help": Rect2(right - 62, top, 62, 65),
		"nav": nav, "play": play, "ritual": ritual, "altar": altar, "altar_height": altar_height,
		"stage_bottom": stage_bottom, "stage_height": stage_height,
		"record": Rect2(left, nav.position.y - 38, minf(380, play.position.x - left - 28), 30)}
	var tabs: Array[Rect2] = []
	for i in range(3):
		tabs.append(Rect2(nav.position.x + i * (nav.size.x + 14) / 3, nav.position.y, (nav.size.x - 28) / 3, nav.size.y))
	result.tabs = tabs
	return result

func backdrop(g, view: Rect2) -> void :

	var source = Rect2(Vector2.ZERO, background_texture.get_size())
	var ratio = view.size.x / view.size.y
	if source.size.x / source.size.y > ratio:
		var width = source.size.y * ratio
		source.position.x = (source.size.x - width) * 0.5
		source.size.x = width
	else:
		var height = source.size.x / ratio
		source.position.y = (source.size.y - height) * 0.5
		source.size.y = height
	g.paint_target.draw_texture_rect_region(background_texture, view, source)

	for lamp in [Vector2(65, 360), Vector2(1745, 322)]:
		var normalized = lamp / Vector2(1836, 856)
		var at = view.position + (normalized * background_texture.get_size() - source.position) / source.size * view.size
		var flicker = 0.8 + 0.12 * sin(g.ui_time * 3.1 + lamp.x) + 0.08 * sin(g.ui_time * 5.3)
		for ring in range(8, 0, -1):
			g.draw_circle(at, ring * 5.5, Color(1, 0.57, 0.16, 0.0035 * flicker))

func label(g, value: String, baseline: Vector2, size: int, color: Color = IVORY, center: bool = true, max_width: float = -1, title: bool = false, outline: int = 2) -> void :
	var font = logo_font if title else label_font
	if max_width > 0:
		while size > 13 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width: size -= 1
	var point = baseline
	if center: point.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	g.paint_target.draw_string_outline(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
	g.paint_target.draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func shape(rect: Rect2, cut: float = 10) -> PackedVector2Array:
	var p = rect.position
	var e = rect.end
	return PackedVector2Array([p + Vector2(cut, 0), Vector2(e.x - cut, p.y), Vector2(e.x, p.y + cut),
		e - Vector2(0, cut), e - Vector2(cut, 0), Vector2(p.x + cut, e.y), Vector2(p.x, e.y - cut), p + Vector2(0, cut)])

func slab(g, rect: Rect2, face: Color, border: Color, cut: float = 12, depth: float = 5) -> void :
	var back = rect
	back.position.y += depth
	g.paint_target.draw_colored_polygon(shape(back, cut), Color("120b1d"))
	g.paint_target.draw_colored_polygon(shape(rect, cut), Color("1a1026"))
	g.paint_target.draw_colored_polygon(shape(rect.grow(-2), cut - 1), border)
	g.paint_target.draw_colored_polygon(shape(rect.grow(-4), cut - 2), Color("25182f"))
	var inner = rect.grow(-6)
	var colors = PackedColorArray()
	for i in range(8): colors.append(face.lightened(0.07) if i < 3 or i == 7 else face.darkened(0.1))
	g.paint_target.draw_polygon(shape(inner, maxf(2, cut - 4)), colors)
	g.paint_target.draw_line(rect.position + Vector2(cut + 3, 6), Vector2(rect.end.x - cut - 3, rect.position.y + 6), Color(1, 0.85, 0.67, 0.24), 1.5, true)
	g.paint_target.draw_line(Vector2(rect.position.x + cut + 3, rect.end.y - 6), rect.end - Vector2(cut + 3, 6), Color(0, 0, 0, 0.26), 2, true)

func corners(g, rect: Rect2, color: Color = Color("d5a65d")) -> void :
	for side in range(4):
		var direction = Vector2(1 if side % 2 == 0 else -1, 1 if side < 2 else -1)
		var point = Vector2(rect.position.x + 5 if side % 2 == 0 else rect.end.x - 5, rect.position.y + 5 if side < 2 else rect.end.y - 5)
		var line = PackedVector2Array([point + direction * Vector2(0, 16), point + direction * Vector2(0, 8), point + direction * Vector2(8, 0), point + direction * Vector2(21, 0)])
		g.paint_target.draw_polyline(line, INK, 6, true)
		g.paint_target.draw_polyline(line, color, 3, true)
		g.draw_circle(point + direction * Vector2(6, 6), 1.6, Color("ffe0a2"))

func logo(g, rect: Rect2) -> void :
	g.paint_target.draw_texture_rect(logo_texture, rect, false)

func register(g, rect: Rect2, action: String) -> void :
	g.buttons.append({"rect": rect, "action": action})

func header(g, d: Dictionary) -> void :
	logo(g, d.title)
	var level: Rect2 = d.level
	slab(g, level, Color("22162f"), Color("b18a52"), 12, 3)
	corners(g, level)
	g.animated_soul(level.position + Vector2(30, 32 + sin(g.ui_time * 2.1) * 2), 43, g.ui_time)
	label(g, "NÍVEL " + str(g.data.player_level), level.position + Vector2(63, 29), 26, IVORY, false, level.size.x * 0.47)
	var count = str(g.data.level_souls) + " / " + str(HordeProgress.level_target(int(g.data.player_level)))
	var count_size = 22
	while label_font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size).x > level.size.x * 0.34 and count_size > 13: count_size -= 1
	label(g, count, Vector2(level.end.x - 16 - label_font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size).x, level.position.y + 29), count_size, MINT, false)
	g.progress_bar(Rect2(level.position + Vector2(62, 44), Vector2(level.size.x - 80, 10)), float(g.data.level_souls) / HordeProgress.level_target(int(g.data.player_level)), MINT)
	slab(g, d.wallet, Color("27172f"), Color("b18a52"), 13, 3)

	g.scenery.sprite(g, g.art.items[1], d.wallet.position + Vector2(30, 33 + sin(g.ui_time * 2) * 1.3), 39, Color.WHITE, sin(g.ui_time * 1.8) * 0.045)
	label(g, str(g.data.wallet), d.wallet.position + Vector2(57, 45), 34, GOLD, false, d.wallet.size.x - 70)
	for action in ["audio", "help"]:
		var rect: Rect2 = d[action]
		var center = rect.get_center()
		slab(g, rect, Color("483054") if rect.has_point(g.get_local_mouse_position()) else Color("2b1c3b"), Color("b18a52"), 12, 3)
		register(g, rect, "settings" if action == "audio" else "help")
		if action == "help": label(g, "?", center + Vector2(0, 14), 37, IVORY, true)
		else: gear(g, center, 18, g.ui_time * 0.35)

func gear(g, point: Vector2, radius: float, time: float) -> void :
	var vertices = PackedVector2Array()
	for i in range(48):
		var angle = time + i * TAU / 48
		var r = radius * (1 if i % 6 in [1, 2, 3, 4] else 0.76)
		vertices.append(point + Vector2(cos(angle), sin(angle)) * r)
	g.paint_target.draw_colored_polygon(vertices, IVORY)
	g.draw_circle(point, radius * 0.5, Color("2b1c3b"))
	g.draw_arc(point, radius * 0.51, 0, TAU, 32, GOLD, 2, true)

func formation(owned: Array) -> Array[Dictionary]:
	var kinds: Array = []
	for kind in owned:
		if int(kind) in [0, 1] and kind not in kinds: kinds.append(kind)
	if kinds.is_empty(): kinds = [0]
	if kinds.size() == 1: return [{"kind": kinds[0], "x": 0.49, "depth": 0.0, "height": 1.0, "phase": 0.0}]
	var result: Array[Dictionary] = []
	for row in range(2):
		var count = 4 if row == 0 else 3
		for i in range(count):
			result.append({"kind": kinds[(i + row) % kinds.size()], "x": (0.12 + i * 0.76 / (count - 1)) if row == 0 else (0.23 + i * 0.54 / (count - 1)), "depth": -105.0 if row == 0 else 0.0, "height": 0.64 if row == 0 else 0.84, "phase": i * 0.7 + row * 0.4})
	return result

func cast(g, d: Dictionary) -> void :
	var view: Rect2 = d.view
	var height: float = d.stage_height
	var floor_y: float = d.stage_bottom
	var point = Vector2(view.position.x + view.size.x * 0.35, floor_y)
	menu_zombie.begin_frame()
	for ring in range(4, 0, -1):
		g.draw_set_transform(point + Vector2(0, 3), 0, Vector2(height * (0.19 + ring * 0.017), 3 + ring * 1.4))
		g.draw_circle(Vector2.ZERO, 1, Color(0.025, 0.013, 0.05, 0.1))
		g.draw_set_transform(Vector2.ZERO)
	menu_zombie.paint(0, point, height, g.ui_time)
	if 3 in g.data.power_owned:
		var fly = point + Vector2(height * 0.365, - height * 0.28 + sin(g.ui_time * 2.3) * 5)
		g.actor.paint(g, 3, fly, height * 0.39, g.ui_time * 1.4, "fly", g.ui_time, 0, Color.WHITE, false, 1, false)

func altar(g, d: Dictionary) -> void :
	var p: Vector2 = d.altar
	var h: float = d.altar_height
	paint_cauldron(g, p, h)
	for i in range(4):
		var t = g.ui_time * 1.2 + i * TAU / 4
		g.animated_soul(p + Vector2(cos(t) * h * 0.29, - h * 0.33 + sin(t) * h * 0.1), 33 + sin(t * 1.5) * 3, g.ui_time + i * 0.29, Color(1, 1, 1, 0.86))
	var rect: Rect2 = d.ritual
	g.paint_target.draw_style_box(panel_style, rect)
	label(g, "RITUAL DA MADRUGADA", rect.position + Vector2(rect.size.x * 0.5, 28), 24, IVORY, true, rect.size.x - 48)
	var amount = float(g.data.ritual_progress)
	if not g.ritual_view.is_empty() and g.ritual_time < 2.5:
		amount = fposmod(float(g.ritual_view.old_progress) + float(g.ritual_view.points) * clampf(g.ritual_time / 2.1, 0, 1), 100)
	g.progress_bar(Rect2(rect.position + Vector2(24, 39), Vector2(rect.size.x - 48, 11)), amount / 100, MINT)
	label(g, str(int(amount)) + " / 100", rect.position + Vector2(rect.size.x * 0.5, 69), 21, IVORY, true)
	if not g.ritual_view.is_empty() and int(g.ritual_view.coins) > 0 and g.ritual_time > 1.7:
		label(g, "+" + str(g.ritual_view.coins) + " MOEDAS", p - Vector2(0, h * 0.6), 22, GOLD, true, rect.size.x)

func paint_cauldron(g, p: Vector2, h: float) -> void :
	var receiving = not g.ritual_view.is_empty() and g.ritual_time < 2.7 and int(g.ritual_view.get("points", 0)) > 0
	var pulse = pow(maxf(0, sin(g.ui_time * (9 if receiving else 2.3))), 2)
	var power = 1.0 + (1.5 * pulse if receiving else 0.2 * pulse)
	g.draw_set_transform(p + Vector2(0, 9), 0, Vector2(h * 0.7, h * 0.3))
	g.draw_circle(Vector2.ZERO, 1, Color(0.15, 1, 0.75, 0.07 * power));g.draw_set_transform(Vector2.ZERO)
	g.scenery.sprite(g, g.art.ritual[1], p, h, Color(1, 1, 1, 1), sin(g.ui_time * 1.9) * (0.013 if receiving else 0.005))
	var liquid = p - Vector2(0, h * 0.168)
	var rx = h * 0.267; var ry = h * 0.059
	g.draw_set_transform(liquid, 0, Vector2(rx, ry))
	g.draw_circle(Vector2.ZERO, 1, Color("127d77"));g.draw_set_transform(Vector2.ZERO)
	var wave = PackedVector2Array()
	for i in range(33):
		var x = -1 + i / 16.0
		wave.append(liquid + Vector2(x * rx, ry * 0.25 * sin(x * 8 + g.ui_time * 3.2) * sqrt(maxf(0, 1 - x * x))))
	for i in range(32, -1, -1):
		var x = -1 + i / 16.0
		wave.append(liquid + Vector2(x * rx, ry * sqrt(maxf(0, 1 - x * x))))
	g.paint_target.draw_colored_polygon(wave, Color(0.11, 0.91, 0.67, 0.88))
	for i in range(3):
		var age = fposmod(g.ui_time * 0.7 + i * 0.33, 1)
		g.draw_set_transform(liquid + Vector2(sin(g.ui_time + i) * rx * 0.17, 0), 0, Vector2(1, 0.22))
		g.draw_arc(Vector2.ZERO, rx * age, 0, TAU, 36, Color(0.65, 1, 0.8, (1 - age) * 0.65), 1.7, true)
		g.draw_set_transform(Vector2.ZERO)
	for i in range(8):
		var age = fposmod(g.ui_time * (0.55 if not receiving else 0.95) + i * 0.137, 1)
		var origin = liquid + Vector2(sin(i * 7.9) * rx * 0.73, cos(i * 2.1) * ry * 0.4)
		var at = origin - Vector2(sin(age * 4 + i) * 3, age * h * 0.115)
		var radius = (2 + sin(i * 3.3) * 0.9) * h / 210
		if age < 0.76:
			g.draw_circle(at, radius * (0.6 + age), Color(0.56, 1, 0.79, 0.65))
			g.draw_arc(at, radius * (0.6 + age), 0, TAU, 12, Color(0.86, 1, 0.87, 0.7), 1, true)
		else:
			for j in range(4):
				var direction = Vector2.from_angle(j * TAU / 4 + i)
				g.paint_target.draw_line(at + direction * radius, at + direction * (radius + 6 * (age - 0.76) / 0.24), Color(0.65, 1, 0.85, (1 - age) * 3), 1.3, true)
	for i in range(5):
		var age = fposmod(g.ui_time * 0.23 + i * 0.21, 1)
		var at = liquid + Vector2(sin(age * 5 + i) * h * 0.12, - age * h * 0.38)
		g.draw_circle(at, h * (0.025 + age * 0.045), Color(0.4, 1, 0.78, sin(age * PI) * 0.055 * power))

func play(g, d: Dictionary) -> void :
	var rect: Rect2 = d.play
	var face = rect
	if g.pressed_button == "play": face.position.y += 3
	g.paint_target.draw_style_box(play_style, face)
	var triangle = face.position + Vector2(62, face.size.y * 0.5)
	g.paint_target.draw_colored_polygon(PackedVector2Array([triangle + Vector2(-12, -19), triangle + Vector2(17, 0), triangle + Vector2(-12, 19)]), INK)
	g.paint_target.draw_colored_polygon(PackedVector2Array([triangle + Vector2(-9, -15), triangle + Vector2(12, 0), triangle + Vector2(-9, 15)]), IVORY)
	label(g, "JOGAR", face.get_center() + Vector2(20, 26), 74, IVORY, true, face.size.x - 112, true, 4)
	register(g, rect, "play")

func nav_icon(g, index: int, point: Vector2) -> void :
	match index:
		0:
			g.scenery.sprite(g, g.art.rigs[1][5], point - Vector2(10, 0), 39, Color.WHITE, 0.65)
			var p = point + Vector2(17, 1)
			g.paint_target.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -19), p + Vector2(13, -4), p + Vector2(5, -4), p + Vector2(5, 16), p + Vector2(-5, 16), p + Vector2(-5, -4), p + Vector2(-13, -4)]), MINT)
		1:
			g.scenery.sprite(g, g.art.power(3, g.ui_time), point, 49)
		2:
			for i in range(3):
				g.scenery.sprite(g, g.art.rigs[[0, 1, 2][i]][0], point + Vector2((i - 1) * 22, abs(i - 1) * 3), 35)
		3:
			g.panel(Rect2(point - Vector2(14, 20), Vector2(28, 41)), Color("657583"), Color("a59fab"), 12, 2, false)
			g.paint_target.draw_line(point + Vector2(0, -12), point + Vector2(0, 9), GOLD, 3, true)
			g.paint_target.draw_line(point + Vector2(-7, -5), point + Vector2(7, -5), GOLD, 3, true)
			g.paint_target.draw_line(point + Vector2(-26, 18), point + Vector2(26, 18), Color("8ca490"), 4, true)
		4:
			g.panel(Rect2(point - Vector2(19, 21), Vector2(38, 42)), Color("e6bf79"), Color("a46f42"), 5, 2, false)
			for j in range(3): g.paint_target.draw_line(point + Vector2(-10, -10 + j * 10), point + Vector2(10, -10 + j * 10), Color("61464c"), 2, true)
			g.paint_target.draw_line(point + Vector2(-21, -21), point + Vector2(23, -21), GOLD, 5, true)
			g.paint_target.draw_line(point + Vector2(-21, 21), point + Vector2(23, 21), GOLD, 5, true)

func navigation(g, d: Dictionary) -> void :
	var titles = ["MERCADO", "COLEÇÃO", "MISSÕES"]
	var actions = ["market", "collection", "missions"]
	for i in range(3):
		var rect: Rect2 = d.tabs[i]
		var hover = rect.has_point(g.get_local_mouse_position())
		var face = rect
		if g.pressed_button == actions[i]: face.position.y += 2
		g.paint_target.draw_style_box(panel_style, face)
		if hover: g.paint_target.draw_colored_polygon(shape(face.grow(-10), 8), Color(1, 0.75, 0.5, 0.06))
		var font_size = 34
		var text_width = label_font.get_string_size(titles[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var group_width = 74 + 12 + text_width
		var group_left = face.get_center().x - group_width * 0.5
		var point = Vector2(group_left + 37, face.get_center().y - 1)
		if i == 0:
			g.scenery.sprite(g, g.art.ritual[2], point, 60, Color.WHITE, sin(g.ui_time * 1.8) * 0.018)
		elif i == 1:
			g.scenery.sprite(g, menu_zombie.face, point + Vector2(-14, -1), 49)
			g.scenery.sprite(g, g.art.rigs[3][0], point + Vector2(18, 3), 43)
		else:
			g.scenery.sprite(g, missions_texture, point, 60, Color.WHITE, - 0.035)
		label(g, titles[i], Vector2(group_left + 86, face.get_center().y + 12), font_size, IVORY, false, face.size.x - 110, false, 3)
		register(g, rect, actions[i])
	slab(g, d.record, Color("25182e"), Color("96714f"), 8, 2)
	label(g, "RECORDE: " + str(g.data.best_souls) + " ALMAS  •  " + str(g.data.best) + " M", d.record.position + Vector2(13, 20), 18, GOLD, false, d.record.size.x - 22)

func paint(g) -> void :
	var d = layout(g.full_rect())
	header(g, d)
	cast(g, d)
	altar(g, d)
	play(g, d)
	navigation(g, d)
	g.effects.paint(g, g.art, g.actor)

func ritual_target(view: Rect2) -> Vector2:
	return layout(view).altar - Vector2(0, 18)
