class_name HordeScene
extends RefCounted

var art: HordeArt
var actor: HordeActor
var civilians: Array[Dictionary] = []
var events: Array[String] = []
var clock = 0.0
var district = -1
var scream_left = 2.8
var comment_left = 3.0
var comment_serial = 0
var comment_rng = RandomNumberGenerator.new()
var crash_left = 5.0
var crash_age = -1.0
var view_left = 0.0
var view_right = 1280.0
var view_top = 0.0
var view_bottom = 720.0

func _init(source: HordeArt, rig: HordeActor) -> void :
	art = source;actor = rig
	reset()

func reset() -> void :
	clock = 0;district = -1;scream_left = 2.8;crash_left = 5;crash_age = -1
	civilians.clear();events.clear();comment_left = 3;comment_serial = 0;comment_rng.seed = 76542
	for i in range(6):
		civilians.append({"x": 120.0 + i * 235, "y": HordeRun.FLOOR - 16 - float(i % 3) * 14, "speed": 85.0 + i * 9, "reverse": i % 3 != 0, "phase": i * 0.21, "variant": i % 3, "speech_left": 0.0, "speech": ""})

func update(dt: float, run: HordeRun) -> void :
	clock += dt
	if district != run.area():
		district = run.area();scream_left = 2.8;crash_left = 4.0;crash_age = -1
	if district != 1 or run.inside_tunnel(): return
	for p in civilians:
		p.x += ( - p.speed if p.reverse else p.speed) * dt - run.speed * dt * 0.38
		p.phase += dt * 1.4;p.speech_left = maxf(0, float(p.speech_left) - dt)
		if p.x < -90: p.x = 1400
		if p.x > 1450: p.x = -70
	comment_left -= dt
	if comment_left <= 0 and run.speech_left <= 0 and run.voice_cooldown <= 0:
		for p in civilians:
			if p.x > view_left + 120 and p.x < view_right - 120:
				p.speech = ["A HORDA CHEGOU!", "CORRE! CORRE!", "SOCORRO!", "OLHA O CARRO!"][comment_serial % 4]
				p.speech_left = 2.0;comment_serial += 1
				run.speech_text = p.speech;run.speech_left = 2.0;run.speech_npc = int(MonsterCatalog.CIVILIANS[int(p.variant)].rig)
				comment_left = comment_rng.randf_range(6.5, 9.5)
				run.speech_cooldown = maxf(run.speech_cooldown, 2.7)
				break
	scream_left -= dt;crash_left -= dt
	if scream_left <= 0:
		events.append("background_scream");scream_left = comment_rng.randf_range(5.5, 7.5)
	if crash_left <= 0:
		crash_age = 0;crash_left = 11.0
	if crash_age >= 0:
		var before = crash_age
		crash_age += dt
		if before < 2.55 and crash_age >= 2.55: events.append("background_crash")
		if crash_age > 3.6: crash_age = -1

func sprite(canvas: Node2D, texture: Texture2D, centre: Vector2, height: float, tint: Color = Color.WHITE, angle: float = 0, reverse: bool = false) -> void :
	var size = texture.get_size() * (height / texture.get_height())
	canvas.draw_set_transform(centre, angle, Vector2(-1 if reverse else 1, 1))
	canvas.draw_texture_rect(texture, Rect2( - size * 0.5, size), false, tint)
	canvas.draw_set_transform(Vector2.ZERO)

func helicopter(canvas: Node2D, centre: Vector2, height: float, time: float, angle: float = 0, tint: Color = Color.WHITE) -> void :
	var texture = art.helicopter
	var size = texture.get_size() * (height / texture.get_height())
	canvas.draw_set_transform(centre, angle, Vector2(-1, 1))
	canvas.draw_texture_rect(texture, Rect2( - size * 0.5, size), false, tint)
	var hub = Vector2(4, - height * 0.42)
	var rotor = size.x * 0.43
	canvas.draw_line(hub - Vector2(rotor, 0), hub + Vector2(rotor, 0), Color(0.12, 0.09, 0.18, tint.a * 0.28), 7, true)
	canvas.draw_line(hub - Vector2(rotor * cos(time * 65), 2 * sin(time * 65)), hub + Vector2(rotor * cos(time * 65), 2 * sin(time * 65)), Color(0.85, 0.8, 0.9, tint.a), 3, true)
	canvas.draw_set_transform(Vector2.ZERO)

func paint_outside(canvas: Node2D, run: HordeRun, time: float, area: int, left: float = 0, right: float = 1280) -> void :
	canvas.draw_rect(Rect2(left, view_top, right - left, view_bottom - view_top), Color("342049"))
	clip_texture(canvas, art.sky, Rect2(view_left, view_top, view_right - view_left, 448 - view_top), left, right)
	for i in range(20):
		canvas.draw_rect(Rect2(left, 380 + i * 10, right - left, 11), Color(0.24, 0.14, 0.31, float(i) / 20 * 0.26))
	for layer in range(3):
		var height = [224.0, 274.0, 254.0][layer]
		var texture = art.world_layers[area][layer]
		var width = texture.get_width() * height / texture.get_height()
		var bottom = HordeRun.FLOOR - [80.0, 5.0, -5.0][layer]
		var offset = fposmod(run.world_px * [0.055, 0.19, 0.48][layer], width)
		for tile in range(-1, 3):
			clip_texture(canvas, texture, Rect2(tile * width - offset, bottom - height, width + 1, height), left, right)
	if area == 0:
		for i in range(2):
			var point = Vector2(fposmod(i * 770 - run.world_px * 0.52, 1540) - 140, HordeRun.FLOOR - 111)
			canvas.draw_circle(point, 42, Color(1, 0.65, 0.23, 0.05 + 0.018 * sin(time * 7 + i)))
			sprite(canvas, art.items[10], point + Vector2(0, 35), 135, Color(0.9, 0.92, 1, 1), sin(time * 2 + i) * 0.035)
	elif area == 1:
		for i in range(5):
			var x = fposmod(i * 313 - run.world_px * 0.48, 1565) - 90
			if x > left and x < right: flame(canvas, Vector2(x, HordeRun.FLOOR - 26), time + i, 26)
		for p in civilians:
			if p.x > left and p.x < right:
				if int(p.variant) == 0:
					art.civil.paint(canvas, {"state": "normal", "civil_clip": "corrida", "civil_time": time + p.phase, "civil_flip": p.reverse}, Vector2(p.x, p.y), 66, Color(0.78, 0.76, 0.85, 0.86))
				else: actor.paint(canvas, int(MonsterCatalog.CIVILIANS[int(p.variant)].rig), Vector2(p.x, p.y - absf(sin(time * 3 + p.variant)) * 6), 66, p.phase, "panic_run", time, 0, Color(0.78, 0.76, 0.85, 0.86), p.reverse)

		if crash_age >= 0:
			var t = crash_age
			var point = Vector2(1040 - t * 135, 210 + minf(t, 2.55) * minf(t, 2.55) * 43)
			for i in range(9):
				var smoke = point + Vector2(17 + i * 17, -12 - i * 13)
				canvas.draw_circle(smoke, 7 + i * 1.6, Color(0.22, 0.13, 0.26, 0.3 - float(i) * 0.024))
			if t < 2.55:
				helicopter(canvas, point, 66, time, 0.12 + t * 0.25, Color(0.7, 0.69, 0.78, 0.88))
				flame(canvas, point + Vector2(30, 7), time, 12)
			else:
				sprite(canvas, art.props[5], Vector2(point.x, HordeRun.FLOOR - 53), 105 * (1 + (t - 2.55) * 0.2), Color(1, 1, 1, 1 - (t - 2.55) / 1.05))
	elif area == 2:
		for i in range(6):
			var x = fposmod(i * 280 - run.world_px * 0.19, 1680) - 80
			for puff in range(4):
				var age = fposmod(time * 0.35 + puff * 0.25 + i * 0.12, 1)
				canvas.draw_circle(Vector2(x + age * 26, 265 - age * 100), 12 + age * 24, Color(0.35, 0.28, 0.44, 0.16 * (1 - age)))
	elif area == 3:
		for i in range(12):
			var point = Vector2(fposmod(i * 142 - run.world_px * 0.48, 1704) - 60, HordeRun.FLOOR - 25)
			var glow = 0.16 + 0.1 * sin(time * 5 - i * 0.55)
			canvas.draw_circle(point, 14, Color(0.54, 0.9, 1, glow));canvas.draw_circle(point, 3, Color(0.7, 0.94, 1, 0.9))
		var beacon = Vector2(fposmod(1020 - run.world_px * 0.19, 1530), 244)
		canvas.draw_colored_polygon(PackedVector2Array([beacon, beacon + Vector2(220 * cos(time * 0.75), -75), beacon + Vector2(240 * cos(time * 0.75), 55)]), Color(1, 0.9, 0.65, 0.035))


func flame(canvas: Node2D, pos: Vector2, time: float, height: float) -> void :
	canvas.draw_circle(pos - Vector2(0, height * 0.4), height * 1.2, Color(1, 0.48, 0.12, 0.07))
	for i in range(3):
		var sway = sin(time * 12 + i * 2) * height * 0.1
		canvas.draw_set_transform(pos + Vector2((i - 1) * height * 0.22, 0), sway * 0.013, Vector2(0.55, 0.9 + sin(time * 9 + i) * 0.18))
		canvas.draw_circle(Vector2(0, - height * 0.4), height * 0.45, Color("f29148") if i != 1 else Color("ffdc87"))
	canvas.draw_set_transform(Vector2.ZERO)


func clip_texture(canvas: Node2D, texture: Texture2D, dest: Rect2, left: float, right: float) -> void :
	var x0 = maxf(left, dest.position.x); var x1 = minf(right, dest.end.x)
	if x1 <= x0: return
	var width = texture.get_width(); var height = texture.get_height()
	var source = Rect2((x0 - dest.position.x) / dest.size.x * width, 0, (x1 - x0) / dest.size.x * width, height)
	canvas.draw_texture_rect_region(texture, Rect2(x0, dest.position.y, x1 - x0, dest.size.y), source)

func paint(canvas: Node2D, run: HordeRun, time: float) -> void :
	paint_outside(canvas, run, time, run.area(), view_left, view_right)
	for t in run.tunnels:
		var entrance = HordeRun.ANCHOR + float(t.entry) - run.world_px
		var exit = entrance + float(t.length)
		if entrance >= view_right or exit <= view_left: continue
		var left = maxf(view_left, entrance); var right = minf(view_right, exit)
		if right > left:
			var width = art.tunnel.get_width() * 720.0 / art.tunnel.get_height()
			var offset = fposmod(run.world_px, width)
			for tile in range(-1, 3): clip_texture(canvas, art.tunnel, Rect2(tile * width - offset, 0, width + 1, 720), left, right)
			for i in range(8):
				var x = fposmod(i * 197 - run.world_px * 0.7, 1576) - 80
				if x > left + 25 and x < right - 25:
					var drip = fposmod(time * 0.5 + i * 0.17, 1)
					canvas.draw_line(Vector2(x, 255 + drip * 150), Vector2(x, 261 + drip * 150), Color(0.55, 0.9, 1, 0.28 * (1 - drip)), 2, true)
					canvas.draw_circle(Vector2(x, HordeRun.FLOOR - 8), 21, Color(0.3, 0.8, 0.85, 0.04 + 0.015 * sin(time * 4 + i)))
			for i in range(5):
				var x = fposmod(i * 302 - run.world_px, 1510) - 40
				if x > left + 15 and x < right - 15:
					canvas.draw_circle(Vector2(x, 300), 80, Color(1, 0.58, 0.22, 0.025 + 0.015 * sin(time * 9 + i)))
					canvas.draw_circle(Vector2(x + sin(time * 2 + i) * 13, 280 + fposmod(time * 26 + i * 40, 80)), 2, Color(1, 0.76, 0.38, 0.35))
			# Existing tunnel texture plus dynamic lanterns: no new assets.
			for i in range(5):
				var lantern_x: float = fposmod(i * 382 - run.world_px * 0.82, 1910) - 85
				if lantern_x <= left + 40 or lantern_x >= right - 40: continue
				var glow_y: float = 195.0
				canvas.draw_line(Vector2(lantern_x, 50), Vector2(lantern_x, glow_y), Color("605171"), 3, true)
				canvas.draw_circle(Vector2(lantern_x, glow_y), 12, Color("ffb45e"))
				canvas.draw_circle(Vector2(lantern_x, glow_y), 39, Color(1.0, 0.61, 0.24, 0.09 + 0.025 * sin(time * 5.0 + i)))
		if exit < view_right: paint_outside(canvas, run, time, int(t.to), maxf(view_left, exit), view_right)

func paint_front(canvas: Node2D, run: HordeRun) -> void :
	for t in run.tunnels:
		for side in range(2):
			var boundary = HordeRun.ANCHOR + float(t.entry) + float(t.length) * side - run.world_px
			if boundary < -680 or boundary > 1960: continue
			var texture = art.tunnel_mouths[side]
			var height = 430.0
			var width = texture.get_width() * height / texture.get_height()

			sprite(canvas, texture, Vector2(boundary - 30, HordeRun.FLOOR - height * 0.5), height)
			if side == 0:
				var box = StyleBoxFlat.new();box.bg_color = Color("2a2037");box.border_color = Color("c9a35c")
				box.set_border_width_all(3);box.set_corner_radius_all(11)
				var point = Vector2(boundary - 40, HordeRun.FLOOR - 345)
				canvas.draw_style_box(box, Rect2(point - Vector2(65, 35), Vector2(130, 70)))
				canvas.draw_string(art.title_font, point + Vector2(-45, -8), "TÚNEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("ffe7ba"))
				var value = str(t.number)
				canvas.draw_string(art.title_font, point + Vector2( - art.title_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x * 0.5, 23), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ffc66a"))
