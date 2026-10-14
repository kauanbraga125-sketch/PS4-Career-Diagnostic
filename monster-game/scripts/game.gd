extends Node2D

const SAVE_PATH="user://noite-da-horda.json"
const CREAM=Color("fff1d3")
const GOLD=Color("ffc66a")
const MINT=Color("9ce4c7")
const PLUM=Color("35213f")
const CORAL=Color("ee917e")

var art=HordeArt.new()
var sound: HordeSound
var runner=HordeRun.new()
var data: Dictionary=MonsterCatalog.defaults()
var screen="home"
var ui_time=0.0
var buttons: Array[Dictionary]=[]
var particles: Array[Dictionary]=[]
var jump_held=false
var jump_touches: Dictionary={}
var toast=""
var toast_left=0.0
var shake=0.0
var flash=0.0
var end_delay=-1.0
var last_save=0.0
var run_challenges: Array[String]=[]
var previous_page="home"
var test_mode=false
var capture_mode=false
var capture_freeze=false
var pressed_button=""

func _ready() -> void:
	Engine.max_fps=60
	test_mode="--self-test" in OS.get_cmdline_user_args()
	capture_mode="--capture" in OS.get_cmdline_user_args()
	if not test_mode and not capture_mode: data=read_save()
	sound=HordeSound.new()
	add_child(sound)
	sound.set_enabled(bool(data.audio))
	sound.set_music("moon_menu")
	if test_mode: call_deferred("run_tests")
	elif capture_mode: call_deferred("capture_preview")

func _process(dt: float) -> void:
	ui_time+=dt
	toast_left=maxf(0,toast_left-dt)
	shake=maxf(0,shake-dt*20)
	flash=maxf(0,flash-dt*1.7)
	for i in range(particles.size()-1,-1,-1):
		var p=particles[i]
		p.life-=dt
		p.pos+=p.velocity*dt
		p.velocity.y+=p.gravity*dt
		if p.life<=0: particles.remove_at(i)
	if end_delay>=0:
		end_delay-=dt
		if end_delay<0: change_screen("results")
	queue_redraw()

func _physics_process(dt: float) -> void:
	if screen!="run" or capture_freeze: return
	runner.advance(dt,jump_held)
	consume_run_events()
	check_challenges()
	last_save+=dt
	if last_save>12:
		last_save=0
		save_game()

func change_screen(next: String) -> void:
	screen=next
	buttons.clear()
	pressed_button=""
	jump_touches.clear()
	jump_held=false
	sound.set_music("midnight_run" if next in ["run","pause"] else "moon_menu")
	queue_redraw()

func start_run() -> void:
	runner.start(data.levels)
	particles.clear()
	run_challenges.clear()
	end_delay=-1
	toast_left=0
	last_save=0
	change_screen("run")

func consume_run_events() -> void:
	for e in runner.drain_events():
		match e.type:
			"coin":
				data.wallet+=int(e.amount)
				sound.play("coin")
				burst(Vector2(e.x,e.y),GOLD,5)
			"recruit":
				sound.play("recruit")
				burst(Vector2(e.x,e.y),MINT,18)
			"jump": sound.play("jump")
			"land":
				sound.play("land")
				burst(Vector2(e.x,e.y),Color("7d708c"),4,false)
			"perk":
				sound.play("perk")
				flash=.32
				burst(Vector2(e.x,e.y),MINT if e.kind==3 else CORAL,35)
				show_toast("MOSCAS MUTANTES! VOE SOBRE OS PERIGOS" if e.kind==3 else "MASCARADOS! DESTRUA OS OBSTÁCULOS",3)
			"perk_end": show_toast("Transformação terminou",1.8)
			"guard":
				sound.play("guard")
				burst(Vector2(e.x,e.y),Color("8de5f0"),20)
			"smash":
				sound.play("smash")
				shake=6
				burst(Vector2(e.x,e.y),CORAL,22)
			"hit":
				sound.play("hit")
				shake=7
				burst(Vector2(e.x,e.y),CORAL,14)
			"finish": finish_run()

func finish_run() -> void:
	if end_delay>=0 or screen not in ["run","pause"]: return
	data.best=maxi(int(data.best),runner.distance())
	data.runs+=1
	end_delay=.65
	jump_held=false
	sound.play("finish")
	save_game()

func check_challenges() -> void:
	var values={"recruits":runner.recruits,"coins":runner.coins,"distance":runner.distance()}
	for challenge in MonsterCatalog.CHALLENGES:
		if challenge.id in data.claimed: continue
		if int(values[challenge.id])>=int(challenge.target):
			data.claimed.append(challenge.id)
			data.wallet+=int(challenge.reward)
			run_challenges.append(challenge.title)
			sound.play("challenge")
			show_toast("DESAFIO CONCLUÍDO  +"+str(challenge.reward)+" MOEDAS",3)
			save_game()

func buy_upgrade(index: int) -> bool:
	if index<0 or index>=MonsterCatalog.UPGRADES.size(): return false
	var item=MonsterCatalog.UPGRADES[index]
	var level=int(data.levels[item.id])
	if level>=int(item.max): show_toast("Esta melhoria já está no máximo."); return false
	var cost=MonsterCatalog.upgrade_cost(item,level)
	if int(data.wallet)<cost:
		show_toast("Faltam "+str(cost-int(data.wallet))+" moedas. Jogue mais uma corrida!")
		return false
	data.wallet-=cost
	data.levels[item.id]=level+1
	sound.play("buy")
	show_toast("Melhoria comprada! Nível "+str(level+1),2)
	save_game()
	return true

func perform_action(action: String) -> void:
	if action.begins_with("buy_"): buy_upgrade(int(action.trim_prefix("buy_"))); return
	match action:
		"play": start_run()
		"shop": previous_page="results" if screen=="results" else "home"; change_screen("shop")
		"monsters": change_screen("monsters")
		"help": change_screen("help")
		"home":
			if screen in ["run","pause"] and not runner.dead:
				runner.finish();consume_run_events();end_delay=-1
			change_screen("home")
		"back": change_screen(previous_page if screen=="shop" else "home")
		"pause": if screen=="run": change_screen("pause")
		"resume": if screen=="pause": change_screen("run")
		"audio":
			data.audio=not bool(data.audio)
			sound.set_enabled(bool(data.audio));save_game()

func press_at(point: Vector2,touch_id: int=-1) -> void:
	for i in range(buttons.size()-1,-1,-1):
		var button=buttons[i]
		if button.rect.has_point(point):
			pressed_button=button.action
			if button.action=="jump":
				jump_touches[touch_id]=true
				jump_held=true
				runner.jump()
			else: perform_action(button.action)
			return
	if screen=="run" and not runner.dead:
		jump_touches[touch_id]=true
		jump_held=true
		runner.jump()

func release_touch(id: int) -> void:
	jump_touches.erase(id)
	jump_held=not jump_touches.is_empty()
	pressed_button=""

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: press_at(event.position,event.index)
		else: release_touch(event.index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: press_at(event.position,-1)
		else: release_touch(-1)
	elif event is InputEventKey and not event.echo:
		if event.keycode==KEY_SPACE:
			if event.pressed and screen=="run": jump_touches[-2]=true;jump_held=true;runner.jump()
			elif not event.pressed: release_touch(-2)
		elif event.pressed and event.keycode in [KEY_ESCAPE,KEY_BACK]:
			if screen=="run": perform_action("pause")
			elif screen=="pause": perform_action("resume")
			elif screen!="home": perform_action("back")

func burst(pos: Vector2,color: Color,count: int,glowing: bool=true) -> void:
	for i in range(count):
		particles.append({"pos":pos,"velocity":Vector2(randf_range(-160,160),randf_range(-240,-30)),"life":randf_range(.35,.8),"max_life":.8,"color":color,"size":randf_range(2,6),"gravity":420.0,"glow":glowing})

func show_toast(message: String,duration: float=2.8) -> void:
	toast=message;toast_left=duration

func text(value: String,pos: Vector2,size: int=22,color: Color=CREAM,heading: bool=false,center: bool=false,outline: int=0) -> void:
	var font=art.title_font if heading else art.body_font
	var point=pos
	if center: point.x-=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*.5
	if outline>0: draw_string_outline(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,outline,Color("1c112b"))
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func wrapped(value: String,pos: Vector2,width: float,size: int=19,color: Color=CREAM,maximum: int=4) -> void:
	var line="";var row=0
	for word in value.split(" "):
		var candidate=line+word+" "
		if art.body_font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and not line.is_empty():
			text(line,pos+Vector2(0,row*(size+9)),size,color)
			row+=1;line=""
			if row>=maximum: return
		line+=word+" "
	if not line.is_empty(): text(line,pos+Vector2(0,row*(size+9)),size,color)

func panel(rect: Rect2,color: Color,border: Color=Color("70496f"),radius: int=20,border_size: int=2,shadow: bool=true) -> void:
	var box=StyleBoxFlat.new()
	box.bg_color=color
	box.border_color=border
	box.set_border_width_all(border_size)
	box.set_corner_radius_all(radius)
	if shadow:
		box.shadow_color=Color(0.04,.02,.09,.55)
		box.shadow_size=4;box.shadow_offset=Vector2(0,6)
	draw_style_box(box,rect)

func button(rect: Rect2,label: String,action: String,color: Color=Color("825aab"),icon: int=-2,size: int=25) -> void:
	var pressed=pressed_button==action
	var face=rect
	if pressed: face.position.y+=3
	panel(face,color.lightened(.06) if pressed else color,color.lightened(.28),18,3)
	draw_line(face.position+Vector2(20,8),face.position+Vector2(face.size.x-20,8),Color(1,1,1,.13),3,true)
	var offset=18.0 if icon>=0 else 0.0
	if icon>=0: item_sprite(icon,Vector2(face.position.x+36,face.get_center().y),42)
	text(label,face.get_center()+Vector2(offset,size*.37),size,CREAM,true,true,2)
	buttons.append({"rect":rect,"action":action})

func item_sprite(index: int,centre: Vector2,height: float,modulate: Color=Color.WHITE) -> void:
	var texture=art.items[clampi(index,0,art.items.size()-1)]
	var size=texture.get_size()
	var draw_size=size*(height/size.y)
	draw_texture_rect(texture,Rect2(centre-draw_size*.5,draw_size),false,modulate)

func creature(kind: int,frame: int,foot: Vector2,height: float,shadow: bool=true,modulate: Color=Color.WHITE) -> void:
	var texture=art.actor(kind,frame)
	var size=texture.get_size()
	var draw_size=size*(height/size.y)
	if shadow:
		draw_set_transform(Vector2(foot.x,HordeRun.FLOOR+4),0,Vector2(height*.25,5))
		draw_circle(Vector2.ZERO,1,Color(0.02,.01,.05,.25))
		draw_set_transform(Vector2.ZERO)
	var origin=foot-Vector2(draw_size.x*.5,draw_size.y*art.baselines[kind])
	draw_texture_rect(texture,Rect2(origin,draw_size),false,modulate)

func currency() -> void:
	panel(Rect2(1000,32,236,62),Color(.14,.09,.2,.90),Color("976b65"),26)
	item_sprite(1,Vector2(1038,62),38)
	text(str(data.wallet),Vector2(1070,77),31,GOLD,true,false,2)

func backdrop() -> void:
	var drift=sin(ui_time*.11)*6
	draw_texture_rect(art.background,Rect2(-12+drift,-4,1304,728),false)
	for i in range(14):
		var x=fmod(i*97.0+ui_time*(7+i*.35),1340)-30
		var y=400+sin(ui_time*.3+i*2.2)*110
		draw_circle(Vector2(x,y),1.6,Color(.75,1,.85,.2+sin(ui_time*2+i)*.1))

func ground(offset: float=0) -> void:
	draw_rect(Rect2(0,HordeRun.FLOOR,1280,146),Color("21182f"))
	draw_rect(Rect2(0,HordeRun.FLOOR,1280,8),Color("6a7772"))
	draw_rect(Rect2(0,HordeRun.FLOOR+8,1280,7),Color("374545"))
	for i in range(38):
		var x=fposmod(i*39-offset,1450)-75
		draw_line(Vector2(x,HordeRun.FLOOR+9),Vector2(x+25,HordeRun.FLOOR+9),Color("879282"),2,true)
		var y=610+posmod(i*17,80)
		draw_line(Vector2(x,y),Vector2(x+13,y+4),Color("3a2b4a"),3,true)

func _draw() -> void:
	buttons.clear()
	backdrop()
	if screen in ["run","pause","results"]:
		draw_run()
	else:
		draw_rect(Rect2(0,0,1280,720),Color(.035,.012,.065,.18))
	match screen:
		"home": draw_home()
		"shop": draw_shop()
		"monsters": draw_monsters()
		"help": draw_help()
		"run": draw_run_hud()
		"pause": draw_pause()
		"results": draw_results()
	if flash>0: draw_rect(Rect2(0,0,1280,720),Color(.62,1,.83,flash*.4))
	if toast_left>0:
		var width=clampf(art.body_font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x+64,360,1150)
		panel(Rect2(640-width*.5,128,width,58),Color(.13,.08,.19,.96),Color("c2ab82"),18)
		text(toast,Vector2(640,165),21,CREAM,false,true)

func draw_home() -> void:
	currency()
	button(Rect2(794,34,176,56),"SOM: ON" if data.audio else "SOM: OFF","audio",Color("51375f"),-2,19)
	text("NOITE",Vector2(83,137),105,CREAM,true,false,11)
	text("DA HORDA",Vector2(82,242),94,GOLD,true,false,11)
	text("Um zumbi. Muitos pesadelos.",Vector2(89,286),26,MINT,false,false,3)
	text("RECRUTE  •  TRANSFORME  •  EVOLUA",Vector2(93,328),17,CREAM,true,false,2)
	creature(1,1+int(ui_time*7)%4,Vector2(191,613+sin(ui_time*3)*3),164,false)
	creature(0,1+int(ui_time*7+.8)%4,Vector2(356,628+sin(ui_time*3+1)*3),219,false)
	creature(2,1+int(ui_time*7+.3)%4,Vector2(576,620+sin(ui_time*3+2)*3),184,false)
	button(Rect2(862,252,343,97),"JOGAR","play",Color("d9974c"),-2,40)
	button(Rect2(862,373,343,72),"MELHORIAS","shop",Color("8054a7"),0,27)
	button(Rect2(862,468,343,72),"MONSTROS","monsters",Color("487385"),11,27)
	button(Rect2(862,563,343,66),"COMO JOGAR","help",Color("4d7468"),4,24)
	panel(Rect2(78,643,620,48),Color(.10,.06,.17,.83),Color("6e5466"),18)
	text("RECORDE  "+str(data.best)+" m",Vector2(102,675),20,GOLD,true)
	text("ALPHA 0.1",Vector2(586,675),15,Color("bbaac8"),true)

func draw_shop() -> void:
	text("MELHORIAS",Vector2(66,105),45,GOLD,true,false,5)
	text("Prepare seu grupo para a próxima fuga.",Vector2(69,147),22,CREAM)
	currency()
	for i in range(4):
		var item=MonsterCatalog.UPGRADES[i]
		var x=64+i*291
		var level=int(data.levels[item.id])
		panel(Rect2(x,184,278,351),Color(.20,.12,.27,.94),Color("785682"),23,3)
		draw_circle(Vector2(x+139,285),72,Color(.50,.33,.59,.32))
		if item.icon<0: creature(0,0,Vector2(x+139,340),130,false)
		else: item_sprite(item.icon,Vector2(x+139,280),124)
		text(item.name,Vector2(x+139,380),21,CREAM,true,true,2)
		for n in range(int(item.max)):
			draw_circle(Vector2(x+111+n*28,407),7,MINT if n<level else Color("665575"))
		wrapped(item.description,Vector2(x+24,452),230,19,Color("ded0e7"),3)
		var full=level>=int(item.max)
		var cost=MonsterCatalog.upgrade_cost(item,level)
		button(Rect2(x+6,558,266,69),"NO MÁXIMO" if full else str(cost)+" MOEDAS","buy_"+str(i),Color("6b7669") if full else Color("9670ba"),-2,23)
	button(Rect2(68,657,218,45),"VOLTAR","back",Color("513c67"),-2,19)
	text("Melhorias permanentes  •  Moedas ganhas ficam com você",Vector2(350,689),18,MINT)

func draw_monsters() -> void:
	text("O ELENCO DA NOITE",Vector2(67,105),43,GOLD,true,false,5)
	text("Criaturas coletáveis e transformações da primeira versão.",Vector2(70,146),21,CREAM)
	for i in range(4):
		var x=64+i*291
		var monster=MonsterCatalog.MONSTERS[i]
		panel(Rect2(x,189,278,417),Color(.18,.11,.25,.94),Color("76527d"),22,3)
		creature(i,1+int(ui_time*6)%4,Vector2(x+139,397),168,false)
		text(monster.name.to_upper(),Vector2(x+139,443),22,monster.color,true,true,2)
		text("RECRUTA" if i<2 else "TRANSFORMAÇÃO",Vector2(x+139,476),16,CREAM,true,true)
		wrapped(monster.description,Vector2(x+23,515),231,17,Color("d9cce3"),3)
	button(Rect2(68,651,218,50),"VOLTAR","back",Color("513c67"),-2,20)

func draw_help() -> void:
	text("COMO JOGAR",Vector2(68,105),44,GOLD,true,false,5)
	var headings=["1. PULE","2. RECRUTE","3. TRANSFORME"]
	var descriptions=["Toque na tela para pular. Segure um pouco para saltar mais alto. Com Pulo Ágil no nível 2, toque de novo no ar para dar salto duplo.","Encontre zumbis e esqueletos na pista. Obstáculos tiram membros do grupo; com cinco criaturas você consegue esmagar carros.","O cristal transforma todos em moscas mutantes. A máscara ativa os mascarados. Colete moedas para comprar melhorias permanentes."]
	for i in range(3):
		var x=68+i*392
		panel(Rect2(x,187,364,382),Color(.18,.11,.26,.94),Color("76527d"),22,3)
		if i==1: creature(0,0,Vector2(x+182,325),110,false)
		else: item_sprite(4 if i==0 else 0,Vector2(x+182,272),103)
		text(headings[i],Vector2(x+182,376),25,GOLD,true,true,2)
		wrapped(descriptions[i],Vector2(x+27,419),310,20,CREAM,5)
	button(Rect2(68,627,240,66),"VOLTAR","back",Color("513c67"),-2,23)
	text("No computador: espaço pula; Esc pausa.",Vector2(350,666),20,MINT)

func draw_run() -> void:
	for i in range(5):
		var x=fposmod(i*347-runner.world_px*.16,1720)-180
		item_sprite(9,Vector2(x,HordeRun.FLOOR-47),94,Color(1,1,1,.58))
	ground(runner.world_px)
	for e in runner.entities:
		if e.taken or e.x< -180 or e.x>1480: continue
		var bob=sin(ui_time*4+e.x*.008)*5
		match e.kind:
			"coin": item_sprite(1,Vector2(e.x,e.y+bob),33)
			"recruit":
				draw_circle(Vector2(e.x,e.y-43),47,Color(.55,1,.73,.09))
				creature(e.variant,0,Vector2(e.x,e.y),99,true)
				text("+1",Vector2(e.x,e.y-113),19,MINT,true,true,2)
			"crystal","mask","shield":
				var icon=0 if e.kind=="crystal" else (11 if e.kind=="mask" else 2)
				draw_circle(Vector2(e.x,e.y+bob),58,Color(.7,.55,1,.07))
				draw_circle(Vector2(e.x,e.y+bob),40,Color(.75,.60,1,.10))
				item_sprite(icon,Vector2(e.x,e.y+bob),73)
			"crate": item_sprite(6,Vector2(e.x,e.y-36),72)
			"car": item_sprite(7,Vector2(e.x,e.y-48),96)
			"spikes": item_sprite(8,Vector2(e.x,e.y-24),48)
			"gap":
				draw_rect(Rect2(e.x,HordeRun.FLOOR,e.width,146),Color("080616"))
				draw_line(Vector2(e.x,HordeRun.FLOOR+4),Vector2(e.x,HordeRun.FLOOR+137),Color("68466e"),4,true)
				draw_line(Vector2(e.x+e.width,HordeRun.FLOOR+4),Vector2(e.x+e.width,HordeRun.FLOOR+137),Color("68466e"),4,true)
				if e.x>HordeRun.ANCHOR: text("PULO!",Vector2(e.x+e.width*.5,HordeRun.FLOOR-28),19,CORAL,true,true,3)
	for i in range(runner.members.size()-1,-1,-1):
		var member=runner.members[i]
		var kind=runner.perk_kind if runner.perk_left>0 else int(member.kind)
		var airborne=member.y<HordeRun.FLOOR-5
		var frame=5 if airborne and kind!=3 else 1+posmod(int(ui_time*11+i*.7),4)
		var foot=Vector2(runner.member_x(i),member.y)
		if i>=6: foot.y-=9
		if kind==3: foot.y+=sin(ui_time*7+i)*5
		if runner.shields>0: draw_arc(foot-Vector2(0,51),59,0,TAU,32,Color(.5,.9,1,.45),3,true)
		var blink=Color(1,1,1,.45) if runner.hit_grace>0 and int(ui_time*14)%2==0 else Color.WHITE
		creature(kind,frame,foot,111 if kind==3 else 105,true,blink)
	for p in particles:
		var color=p.color
		color.a=clampf(p.life/p.max_life,0,1)
		if p.glow: draw_circle(p.pos,p.size*2,Color(color.r,color.g,color.b,color.a*.10))
		draw_circle(p.pos,p.size,color)

func draw_run_hud() -> void:
	panel(Rect2(28,24,214,88),Color(.12,.07,.19,.91),Color("776077"),20)
	text("FUGA",Vector2(49,54),15,MINT,true)
	text(str(runner.distance())+" m",Vector2(48,94),29,CREAM,true,false,2)
	panel(Rect2(259,24,197,88),Color(.12,.07,.19,.91),Color("776077"),20)
	text("HORDA",Vector2(280,54),15,MINT,true)
	text(str(runner.members.size())+" CRIATURAS",Vector2(280,94),20,CREAM,true)
	panel(Rect2(473,24,189,88),Color(.12,.07,.19,.91),Color("776077"),20)
	item_sprite(1,Vector2(511,68),42)
	text(str(runner.coins),Vector2(545,83),28,GOLD,true,false,2)
	if runner.perk_left>0:
		panel(Rect2(679,24,345,88),Color(.20,.10,.29,.94),Color("be99df"),20)
		item_sprite(0 if runner.perk_kind==3 else 11,Vector2(714,68),46)
		text("MOSCA MUTANTE" if runner.perk_kind==3 else "MASCARADOS",Vector2(749,57),19,MINT,true)
		text(str(ceili(runner.perk_left))+" segundos",Vector2(749,88),20,CREAM)
		var duration=(7.0 if runner.perk_kind==3 else 9.0)+int(data.levels.perk)*2
		draw_rect(Rect2(749,99,248*runner.perk_left/duration,4),MINT)
	button(Rect2(1160,28,83,73),"II","pause",Color("513565"),-2,27)
	text("NÉVOA DO CEMITÉRIO",Vector2(32,148),17,Color("bc9bcf"),true,false,2)
	button(Rect2(1073,578,170,107),"PULAR","jump",Color("8753aa"),-2,26)
	if runner.world_px<1800:
		panel(Rect2(390,635,557,53),Color(.12,.07,.19,.9),Color("736377"),20)
		text("TOQUE PARA PULAR  •  SEGURE PARA IR MAIS ALTO",Vector2(668,669),17,CREAM,true,true)
	elif int(data.levels.jump)>=2:
		text("SALTO DUPLO LIBERADO",Vector2(683,675),16,MINT,true,true,2)

func draw_pause() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.04,.015,.08,.68))
	panel(Rect2(401,147,478,429),Color("31203e"),Color("ac8bb9"),26,4)
	text("PAUSA",Vector2(640,236),45,GOLD,true,true,4)
	button(Rect2(458,286,364,75),"CONTINUAR","resume",Color("9370b6"),-2,27)
	button(Rect2(458,385,364,67),"SOM: ON" if data.audio else "SOM: OFF","audio",Color("53736e"),-2,25)
	button(Rect2(458,477,364,65),"ENCERRAR CORRIDA","home",Color("765269"),-2,22)

func draw_results() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.035,.012,.07,.70))
	panel(Rect2(238,94,804,487),Color(.18,.10,.25,.97),Color("b79ac0"),26,4)
	text("FIM DA FUGA",Vector2(640,178),48,GOLD,true,true,5)
	text("Sua horda descansa. As melhorias ficam.",Vector2(640,224),23,CREAM,false,true)
	text(str(runner.distance())+" m",Vector2(640,309),57,CREAM,true,true,4)
	text("RECORDE  "+str(data.best)+" m",Vector2(640,350),20,MINT,true,true)
	item_sprite(1,Vector2(469,410),48)
	text("+"+str(runner.coins)+" MOEDAS",Vector2(514,423),28,GOLD,true)
	text(str(runner.recruits)+" criaturas recrutadas",Vector2(640,474),21,CREAM,false,true)
	text("CARTEIRA  "+str(data.wallet)+" moedas",Vector2(640,517),19,Color("c9b4d8"),false,true)
	button(Rect2(238,615,228,73),"MENU","home",Color("5d426f"),-2,25)
	button(Rect2(488,615,285,73),"MELHORIAS","shop",Color("845eaa"),-2,25)
	button(Rect2(795,615,247,73),"DE NOVO","play",Color("c78a4b"),-2,27)

func validate_save(value) -> Dictionary:
	if not value is Dictionary or int(value.get("version",0))!=1: return MonsterCatalog.defaults()
	var result=MonsterCatalog.defaults()
	result.wallet=clampi(int(value.get("wallet",120)),0,9999999)
	result.best=clampi(int(value.get("best",0)),0,9999999)
	result.runs=maxi(0,int(value.get("runs",0)))
	result.audio=bool(value.get("audio",true))
	var raw_levels=value.get("levels",{})
	if raw_levels is Dictionary:
		for item in MonsterCatalog.UPGRADES: result.levels[item.id]=clampi(int(raw_levels.get(item.id,0)),0,int(item.max))
	var claimed=value.get("claimed",[])
	if claimed is Array:
		for challenge in MonsterCatalog.CHALLENGES:
			if challenge.id in claimed: result.claimed.append(challenge.id)
	return result

func read_save(path: String=SAVE_PATH) -> Dictionary:
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and int(parsed.get("version",0))==1: return validate_save(parsed)
	return MonsterCatalog.defaults()

func save_game(path: String=SAVE_PATH) -> bool:
	if (test_mode or capture_mode) and path==SAVE_PATH: return true
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data));file.flush();file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path+".bak")
		if DirAccess.rename_absolute(path,path+".bak")!=OK: return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED and is_instance_valid(sound):
		if screen=="run": change_screen("pause")
		save_game()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(sound):
		if screen=="run": perform_action("pause")
		elif screen=="pause": perform_action("resume")
		elif screen!="home": perform_action("back")
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(sound): save_game()

func run_tests() -> void:
	var suite=load("res://tests/self_test.gd").new()
	add_child(suite)
	await suite.run(self)

func capture_frame(path: String) -> void:
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("HORDE_CAPTURE "+path)

func capture_preview() -> void:
	await get_tree().create_timer(.5).timeout
	var path=OS.get_environment("HORDE_CAPTURE_PATH")
	if path.is_empty(): path="user://NoiteDaHorda-menu.png"
	var base=path.get_basename().trim_suffix("-menu")
	await capture_frame(base+"-menu.png")
	perform_action("shop")
	await capture_frame(base+"-shop.png")
	perform_action("monsters")
	await capture_frame(base+"-monsters.png")
	start_run();capture_freeze=true
	runner.entities.clear()
	runner.add_member(1);runner.add_member(0)
	runner.add_entity("crate",830)
	runner.add_entity("car",1190,HordeRun.FLOOR,0,155)
	for i in range(6): runner.add_entity("coin",600+i*74,HordeRun.FLOOR-130)
	runner.add_entity("crystal",1030,HordeRun.FLOOR-92)
	runner.world_px=1100
	runner.jump()
	for i in range(11): runner.advance(1.0/60,true)
	consume_run_events()
	await capture_frame(base+"-run.png")
	runner.grant_perk(3);consume_run_events()
	for i in range(60): runner.advance(1.0/60,false)
	consume_run_events();toast_left=0
	await capture_frame(base+"-perk.png")
	get_tree().quit()
