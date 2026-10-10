class_name StreetHUD
extends Control

const INK = Color("10242e")
const PAPER = Color("f1e9d7")
const GOLD = Color("efbc65")
const TEAL = Color("5cbbc0")
var game
var map_open = false
var credits_open = false
var show_briefing = false
var font: Font
var waypoint = Vector3.ZERO
var has_waypoint = false

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func ui_scale() -> float:
	return minf(get_viewport_rect().size.x/1280,get_viewport_rect().size.y/720)

func text_at(p: Vector2,value: String,font_size: int = 20,color: Color = PAPER) -> void:
	draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func paragraph(p: Vector2,value: String,width: float,font_size: int = 20,color: Color = PAPER) -> void:
	var line = ""
	var y = p.y
	for word in value.split(" "):
		if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width and not line.is_empty():
			text_at(Vector2(p.x,y),line,font_size,color)
			y += font_size*1.45
			line = ""
		line += word+" "
	if not line.is_empty(): text_at(Vector2(p.x,y),line,font_size,color)

func panel(rect: Rect2,color: Color = Color(0.045,0.095,0.12,0.86)) -> void:
	draw_style_box(style(color),rect)

func style(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	return s

func button(rect: Rect2,title: String,subtitle: String="",highlight: bool=false) -> void:
	panel(rect,GOLD if highlight else Color(0.12,0.23,0.28,0.94))
	text_at(rect.position+Vector2(20,29),title,22,INK if highlight else PAPER)
	if not subtitle.is_empty(): text_at(rect.position+Vector2(20,49),subtitle,13,Color("30444c") if highlight else Color("a5b8bb"))

func _draw() -> void:
	if not font or not game or not game.player: return
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*ui_scale())
	if credits_open:
		draw_credits()
		return
	if map_open:
		draw_map()
		return
	if not game.running:
		draw_menu()
		return
	draw_minimap(Rect2(24,26,190,160))
	text_at(Vector2(25,208),CityWorld.district(game.focus_position()),16)
	panel(Rect2(234,26,690,102))
	var m = game.missions
	text_at(Vector2(254,55),"%02d / 10    %s" % [mini(m.index+1,10),StreetMissions.STORIES[m.index][0].to_upper() if m.index<10 else "CIDADE LIVRE"],18,GOLD)
	paragraph(Vector2(254,84),m.objective,650,18)
	if m.countdown>0: text_at(Vector2(836,55),"%d:%02d" % [int(m.countdown)/60,int(m.countdown)%60],20)
	panel(Rect2(947,26,243,101))
	text_at(Vector2(966,57),"R$ %s" % game.money,22)
	text_at(Vector2(966,87),"ALERTA  " + "●".repeat(int(ceil(game.heat/20.0))) if game.heat>0 else "LIVRE",16,GOLD if game.heat>0 else TEAL)
	button(Rect2(1206,24,50,48),"II")
	panel(Rect2(24,234,190,62))
	text_at(Vector2(38,254),"SAÚDE",11,Color("a6b8b6"))
	draw_rect(Rect2(38,263,160,6),Color("384b4e"))
	draw_rect(Rect2(38,263,160*game.player.health/100,6),TEAL)
	draw_rect(Rect2(38,279,160*game.player.stamina/100,3),GOLD)
	var p = game.player
	var label = "SEM ARMA  /  explore os marcadores"
	if p.weapon>=0: label = "%s  %d / %d" % [StreetPlayer.WEAPONS[p.weapon],p.magazines[p.weapon],p.reserve[p.weapon]]
	panel(Rect2(850,151,390,52))
	text_at(Vector2(870,184),"RECARREGANDO..." if p.reload_left>0 else label,18)
	if p.vehicle:
		panel(Rect2(497,584,286,102))
		text_at(Vector2(520,628),"%03d" % int(absf(p.vehicle.speed)*3.6),40)
		text_at(Vector2(618,626),"km/h",17,Color("a9bebd"))
		text_at(Vector2(520,663),"MOTO" if p.vehicle.motorcycle else "CARRO",15,TEAL)
		text_at(Vector2(622,663),"ESTADO %d%%" % int(p.vehicle.health),13)
	else:
		draw_line(Vector2(630,360),Vector2(638,360),PAPER,2)
		draw_line(Vector2(646,360),Vector2(654,360),PAPER,2)
		draw_line(Vector2(642,348),Vector2(642,356),PAPER,2)
		draw_line(Vector2(642,364),Vector2(642,372),PAPER,2)
	# The complete mobile control layer remains visible in desktop previews.
	draw_circle(Vector2(155,570),80,Color(0.04,0.09,0.12,0.38))
	draw_arc(Vector2(155,570),79,0,TAU,48,Color(0.85,0.9,0.87,0.35),2)
	draw_circle(Vector2(155,570)+game.controls.joystick*54,29,Color(0.9,0.92,0.87,0.53))
	text_at(Vector2(110,677),"DIRIGIR" if p.vehicle else "MOVER",12)
	var titles = {"fire":"ATIRAR","enter":"SAIR" if p.vehicle else "ENTRAR","jump":"FREIO" if p.vehicle else "PULAR","reload":"RECARGA","weapon":"ARMA","sprint":"CORRER"}
	for action in titles:
		if p.vehicle and action in ["fire","reload","sprint","weapon"]: continue
		var r: Rect2 = game.controls.areas()[action]
		panel(r,Color(0.18,0.30,0.33,0.68) if not game.controls.states.get(action,false) else Color(0.78,0.57,0.25,0.86))
		text_at(r.position+Vector2(10,r.size.y/2+5),titles[action],14)
	text_at(Vector2(927,689),"ARRASTE PARA OLHAR",12,Color("d1d6ca"))
	if game.notice_time>0:
		panel(Rect2(342,612,570,72),Color(0.035,0.085,0.105,0.90))
		paragraph(Vector2(365,640),game.notice,525,18)
	text_at(Vector2(20,710),"PORTO LIVRE  /  ALPHA 0.2     %d FPS  ·  %s" % [int(game.fps),["LEVE","EQUILIBRADO","ALTO"][game.quality]],11,Color("d0d8cf"))
	if game.damage_flash>0: draw_rect(Rect2(0,0,1280,720),Color(0.7,0.05,0.03,game.damage_flash*0.45))

func draw_menu() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.025,0.06,0.085,0.90))
	draw_rect(Rect2(720,0,560,720),Color(0.025,0.07,0.09,0.63))
	text_at(Vector2(80,75),"KAUAN  /  UM MUNDO PARA EXPLORAR",15,TEAL)
	text_at(Vector2(74,181),"PORTO",92)
	text_at(Vector2(74,269),"LIVRE",92,GOLD)
	text_at(Vector2(80,315),"Seis distritos. Dez histórias. Seu caminho.",21)
	text_at(Vector2(80,350),"ANDROID  ·  OFFLINE  ·  ALPHA 0.2",13,Color("a2b9bb"))
	button(Rect2(80,386,540,66),"CONTINUAR" if game.missions.index>0 or game.saved.size()>0 else "EXPLORAR PORTO LIVRE","Toque para jogar · progresso salvo automaticamente",true)
	button(Rect2(80,468,540,62),"QUALIDADE: "+["LEVE","EQUILIBRADA","ALTA"][game.quality],"Toque para alternar · resolução 3D adaptativa")
	button(Rect2(80,546,174,62),"EFEITOS: "+("SIM" if game.sound.enabled else "NÃO"))
	button(Rect2(268,546,170,62),"MÚSICA: "+("SIM" if game.sound.music_enabled else "NÃO"))
	button(Rect2(452,546,168,62),"MAPA")
	button(Rect2(80,618,180,44),"CRÉDITOS")
	text_at(Vector2(80,667),"Texturas e modelos 3D · recomendado para celulares potentes",14,Color("9eafb0"))
	text_at(Vector2(775,80),"SUA HISTÓRIA",15,TEAL)
	for i in range(10):
		var color = GOLD if i==game.missions.index else (TEAL if i<game.missions.index else Color("71878c"))
		var status = "✓" if i<game.missions.index else "%02d" % (i+1)
		text_at(Vector2(775,124+i*30),status+"   "+StreetMissions.STORIES[i][0],19,color)
	if game.missions.index<10:
		paragraph(Vector2(775,468),StreetMissions.STORIES[game.missions.index][1],410,18)
	text_at(Vector2(775,586),"NO CELULAR",13,TEAL)
	paragraph(Vector2(775,611),"Analógico à esquerda. Arraste à direita para olhar. Aproxime-se para recolher armas.",420,15)
	text_at(Vector2(775,675),"PC: WASD · mouse · E · espaço · R · Tab · M",13,Color("93a9ac"))

func map_point(p: Vector3,rect: Rect2,center: Vector3,span: float) -> Vector2:
	return rect.get_center()+Vector2(p.x-center.x,p.z-center.z)*rect.size/span

func draw_minimap(rect: Rect2) -> void:
	panel(rect,Color("253c43"))
	var pos = game.focus_position()
	var span = 290.0
	for x in range(-6,7):
		var a = map_point(Vector3(x*120,0,pos.z),rect,pos,span)
		if a.x>rect.position.x and a.x<rect.end.x: draw_line(Vector2(a.x,rect.position.y),Vector2(a.x,rect.end.y),Color("7a8c86"),4)
	for z in range(-6,7):
		var a = map_point(Vector3(pos.x,0,z*120),rect,pos,span)
		if a.y>rect.position.y and a.y<rect.end.y: draw_line(Vector2(rect.position.x,a.y),Vector2(rect.end.x,a.y),Color("7a8c86"),4)
	for node in game.pickups:
		if is_instance_valid(node):
			var point = map_point(node.position,rect,pos,span)
			if rect.has_point(point): draw_circle(point,3,GOLD)
	if game.missions.index<10:
		var target = map_point(game.missions.current_target(),rect,pos,span)
		target.x = clampf(target.x,rect.position.x+8,rect.end.x-8)
		target.y = clampf(target.y,rect.position.y+8,rect.end.y-8)
		draw_circle(target,6,GOLD)
	var center_point = rect.get_center()
	draw_circle(center_point,5,PAPER)
	draw_line(center_point,center_point+Vector2(-sin(game.camera_yaw),-cos(game.camera_yaw))*13,PAPER,3)
	text_at(rect.position+Vector2(8,17),"N  ↑",11)
	text_at(rect.position+Vector2(8,rect.size.y-8),"TOQUE: MAPA",10)

func draw_map() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("0d222c"))
	text_at(Vector2(40,54),"PORTO LIVRE  /  MAPA",27)
	text_at(Vector2(40,84),"1,44 × 1,44 km · toque no mapa para marcar um local",15,TEAL)
	var r = Rect2(292,110,790,552)
	draw_rect(r,Color("7d8871"))
	var colors = [Color("6e876f"),Color("9d9a88"),Color("838d89"),Color("76896a"),Color("a5987b"),Color("829f9b")]
	var names = ["SERRA VERDE","CENTRO","INDUSTRIAL","CAMPUS / PARQUE","VILA ANTIGA","PORTO / ORLA"]
	for i in range(6):
		var area = Rect2(r.position+Vector2(i%3*r.size.x/3,(i/3)*r.size.y/2),Vector2(r.size.x/3,r.size.y/2))
		draw_rect(area,colors[i])
		text_at(area.position+Vector2(14,24),names[i],13,INK)
	for n in range(13):
		var x = r.position.x+n*r.size.x/12
		var y = r.position.y+n*r.size.y/12
		draw_line(Vector2(x,r.position.y),Vector2(x,r.end.y),Color("d5cebb"),3)
		draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color("d5cebb"),3)
	for v in game.vehicles:
		if is_instance_valid(v): draw_circle(map_point(v.position,r,Vector3.ZERO,1440),3,Color("174d60"))
	for p in game.pickups:
		if is_instance_valid(p): draw_circle(map_point(p.position,r,Vector3.ZERO,1440),4,GOLD)
	if game.missions.index<10: draw_circle(map_point(game.missions.current_target(),r,Vector3.ZERO,1440),9,GOLD)
	draw_circle(map_point(game.focus_position(),r,Vector3.ZERO,1440),7,PAPER)
	draw_circle(map_point(Vector3(60,0,18),r,Vector3.ZERO,1440),5,Color("1b7d80"))
	if has_waypoint:
		var point = map_point(waypoint,r,Vector3.ZERO,1440)
		draw_circle(point,11,Color("ad4140"),false,3)
		text_at(Vector2(40,402),"MARCADOR",14,GOLD)
		text_at(Vector2(40,431),"%d m de você" % int(waypoint.distance_to(game.focus_position())),18)
	text_at(Vector2(40,161),"●  Você",20,PAPER)
	text_at(Vector2(40,200),"●  Objetivo / armas",18,GOLD)
	text_at(Vector2(40,239),"●  Veículos",18,TEAL)
	text_at(Vector2(40,288),"OFICINA",15,TEAL)
	paragraph(Vector2(40,318),"Interaja na oficina para recuperar saúde, munição e veículos próximos.",216,17)
	button(Rect2(40,571,215,63),"VOLTAR", "M / voltar do Android",true)

func draw_credits() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("10242e"))
	text_at(Vector2(80,90),"PORTO LIVRE / CRÉDITOS",36,GOLD)
	var rows = [
		"Personagens: MakeHuman Community — CC0.",
		"Texturas: artistas da Poly Haven — CC0. polyhaven.com/license",
		"Car Concept: Eric Chadwick / Darmstadt Graphics Group GmbH, © 2024 — CC BY 4.0.",
		"Carro adaptado: malha simplificada, texturas reduzidas, escala e materiais ajustados.",
		"Fonte: github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CarConcept",
		"Licença: creativecommons.org/licenses/by/4.0/",
		"Moto: Teh_Bucket. Árvore: musdasch, Yughues e para — CC0 / OpenGameArt.",
		"Wednesday Night: Zane Little Music. Efeitos: rubberduck. Motor: domasx2 — CC0.",
		"Engine Godot: colaboradores do Godot — MIT. godotengine.org/license"
	]
	for i in range(rows.size()): text_at(Vector2(80,155+i*45),rows[i],19)
	button(Rect2(80,625,220,55),"VOLTAR", "",true)

func menu_click(p: Vector2) -> void:
	if credits_open:
		if Rect2(80,625,220,55).has_point(p): credits_open = false
		return
	if map_open:
		if Rect2(40,571,215,63).has_point(p): game.toggle_pause(); return
		var rect = Rect2(292,110,790,552)
		if rect.has_point(p):
			var v = (p-rect.get_center())/rect.size*1440
			waypoint = CityWorld.ground(Vector3(v.x,0,v.y))
			has_waypoint = true
		return
	if Rect2(80,386,540,66).has_point(p): game.start_game()
	elif Rect2(80,468,540,62).has_point(p):
		game.set_quality((game.quality+1)%3)
		game.save_game()
	elif Rect2(80,546,174,62).has_point(p):
		game.sound.enabled = not game.sound.enabled
		game.save_game()
	elif Rect2(268,546,170,62).has_point(p):
		game.sound.music_enabled = not game.sound.music_enabled
		game.save_game()
	elif Rect2(452,546,168,62).has_point(p): map_open=true
	elif Rect2(80,618,180,44).has_point(p): credits_open=true
