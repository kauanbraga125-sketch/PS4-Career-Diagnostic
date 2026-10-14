extends Node2D

const SAVE_PATH="user://noite-da-horda.json"
const CREAM=Color("fff1d3")
const GOLD=Color("ffc66a")
const MINT=Color("9ce4c7")
const PLUM=Color("35213f")
const CORAL=Color("ee917e")

var art=HordeArt.new()
var actor=HordeActor.new(art)
var scenery=HordeScene.new(art,actor)
var effects=HordeEffects.new()
var last_stats: Dictionary={}
var trail_tick=0.0
var voice_tick=0.0
var coin_pulse=0.0
var sound: HordeSound
var runner=HordeRun.new()
var data: Dictionary=MonsterCatalog.defaults()
var screen="home"
var ui_time=0.0
var buttons: Array[Dictionary]=[]
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
	capture_mode="--capture" in OS.get_cmdline_user_args() or "--motion-preview" in OS.get_cmdline_user_args()
	if not test_mode and not capture_mode: data=read_save()
	sound=HordeSound.new()
	add_child(sound)
	sound.set_enabled(bool(data.audio))
	sound.set_music("moon_menu")
	if test_mode: call_deferred("run_tests")
	elif "--motion-preview" in OS.get_cmdline_user_args(): call_deferred("motion_preview")
	elif capture_mode: call_deferred("capture_preview")

func _process(dt: float) -> void:
	if capture_freeze:
		queue_redraw()
		return
	if not capture_freeze: ui_time+=dt
	toast_left=maxf(0,toast_left-dt)
	shake=maxf(0,shake-dt*20)
	flash=maxf(0,flash-dt*1.7)
	coin_pulse=maxf(0,coin_pulse-dt*4)
	position=Vector2(sin(ui_time*83),cos(ui_time*71))*shake*.45 if screen=="run" else Vector2.ZERO
	if screen=="run" and not capture_freeze: update_run_visuals(dt)
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
	sound.set_area(runner.area(),next=="run" and not runner.dead)
	queue_redraw()

func start_run() -> void:
	runner.start(data.levels,0,int(data.skin),data.areas)
	effects.clear()
	scenery.reset();voice_tick=1.8
	run_challenges.clear()
	last_stats={}
	trail_tick=0
	end_delay=-1
	toast_left=0
	last_save=0
	change_screen("run")

func consume_run_events() -> void:
	for e in runner.drain_events():
		var point=Vector2(float(e.get("x",HordeRun.ANCHOR)),float(e.get("y",HordeRun.FLOOR)))
		match e.type:
			"coin":
				data.wallet+=int(e.amount);coin_pulse=1
				sound.play("coin")
				effects.spark(point,GOLD,5)
				effects.pickup(point,1,Vector2(511,68))
			"recruit":
				sound.play("recruit")
				if not runner.members.is_empty(): sound.play_monster(int(runner.members[-1].kind))
				effects.spark(point,MINT,18)
				effects.ring(point,MINT)
			"jump":
				sound.play("jump")
				if point.y>=HordeRun.FLOOR-4: effects.dust(point,10,1.2)
				effects.ring(point,MINT)
			"step": effects.dust(point,2,.65)
			"land":
				if e.get("leader",false): sound.play("land")
				effects.dust(point,8,1.15)
			"wing": effects.spark(point,Color("c39cf3"),8)
			"perk":
				sound.play("perk");flash=.25
				var color=Color("c39cf3") if e.kind==3 else CORAL
				effects.spark(point,color,35);effects.ring(point,color)
				effects.pickup(point,0 if e.kind==3 else 11,point+Vector2(25,-20))
				sound.play_monster(int(e.kind))
				show_toast("MOSCA: SEGURE PARA DESCER, SOLTE PARA SUBIR" if e.kind==3 else "MASCARADOS! DESTRUA OS OBSTÁCULOS",2.4)
			"perk_end":
				effects.spark(point,Color("c39cf3"),16)
				show_toast("Transformação terminou",1.5)
			"boost":
				sound.play("perk");flash=.20
				effects.spark(point,GOLD,30);effects.ring(point,GOLD)
				effects.pickup(point,5,Vector2(HordeRun.ANCHOR,HordeRun.FLOOR-70))
				show_toast("FRENESI! VELOCIDADE E MOEDAS EM DOBRO",2.4)
			"guard":
				sound.play("guard")
				effects.spark(point,Color("8de5f0"),20);effects.ring(point,Color("8de5f0"))
			"smash":
				sound.play("smash");shake=6
				var object_kind=str(e.get("object","crate"))
				effects.smash(point,object_kind)
				if MonsterCatalog.VEHICLES.has(object_kind): show_toast("VEÍCULO VIRADO! +"+str(MonsterCatalog.VEHICLES[object_kind].rescues)+" CRIATURAS",1.7)
			"hit":
				sound.play_monster(int(e.kind),true);shake=7
				effects.death(int(e.kind),point)
			"shot": sound.play("gunshot",-17)
			"explosion": sound.play("explosion",-14);effects.explosion(point);shake=8
			"tunnel": sound.play("tunnel",-18)
			"area":
				sound.set_area(int(e.area),true)
				show_toast(MonsterCatalog.AREAS[int(e.area)].name.to_upper(),2.0)
			"recovery": show_toast("REAGRUPE A HORDA! MAIS RECRUTAS À FRENTE",2.2)
			"finish": finish_run()

func finish_run() -> void:
	if end_delay>=0 or screen not in ["run","pause"]: return
	data.best=maxi(int(data.best),runner.distance())
	data.runs+=1
	end_delay=1.0
	jump_held=false
	sound.play("finish")
	sound.set_area(0,false)
	save_game()

func check_challenges() -> void:
	var values=runner.stats()
	var all_complete=true
	for challenge in MonsterCatalog.active_missions(int(data.mission_tier)):
		if challenge.key in data.claimed: continue
		var current=int(values.get(challenge.stat,0))
		var progress=int(data.mission_progress.get(challenge.id,0))
		if challenge.mode=="sum":
			progress+=maxi(0,current-int(last_stats.get(challenge.stat,0)))
		else: progress=maxi(progress,current)
		data.mission_progress[challenge.id]=mini(progress,int(challenge.target))
		if progress>=int(challenge.target):
			data.claimed.append(challenge.key)
			data.wallet+=int(challenge.reward)
			data.missions_completed+=1
			run_challenges.append(challenge.title)
			sound.play("challenge")
			show_toast("MISSÃO CONCLUÍDA  +"+str(challenge.reward)+" MOEDAS",2.5)
			save_game()
		else: all_complete=false
	last_stats=values.duplicate()
	if all_complete:
		data.mission_tier+=1
		data.claimed.clear();data.mission_progress.clear()
		show_toast("NOVAS MISSÕES! CAPÍTULO "+str(int(data.mission_tier)+1),2.5)
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
	if action.begins_with("skin_"): buy_skin(int(action.trim_prefix("skin_"))); return
	if action.begins_with("area_"): buy_area(int(action.trim_prefix("area_"))); return
	match action:
		"play": start_run()
		"shop": previous_page="results" if screen=="results" else "home"; change_screen("shop")
		"monsters": change_screen("monsters")
		"worlds": change_screen("worlds")
		"missions": change_screen("missions")
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
	effects.spark(pos,color,count)

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
	if shadow:
		draw_set_transform(Vector2(foot.x,HordeRun.FLOOR+4),0,Vector2(height*.22,4))
		draw_circle(Vector2.ZERO,1,Color(.02,.01,.05,.25))
		draw_set_transform(Vector2.ZERO)
	var state="idle" if frame==0 else ("rise" if frame==5 else "run")
	actor.paint(self,kind,foot,height,ui_time*2.7,state,ui_time,0,modulate)

func currency() -> void:
	panel(Rect2(1000,32,236,62),Color(.14,.09,.2,.90),Color("976b65"),26)
	item_sprite(1,Vector2(1038,62),38)
	text(str(data.wallet),Vector2(1070,77),31,GOLD,true,false,2)

func backdrop() -> void:
	if screen in ["run","pause","results"]:
		scenery.paint(self,runner,ui_time)
	else:
		draw_texture_rect(art.background,Rect2(-12+sin(ui_time*.11)*6,-4,1304,728),false)
	for i in range(18):
		var x=fposmod(i*83.0+ui_time*(7+i*.35)-runner.world_px*.10,1340)-30
		var y=405+sin(ui_time*.5+i*2.2)*115
		draw_circle(Vector2(x,y),3.5,Color(.75,1,.85,.035))
		draw_circle(Vector2(x,y),1.3,Color(.75,1,.85,.20+sin(ui_time*2+i)*.10))
	for i in range(3):
		var pos=Vector2(fposmod(ui_time*(25+i*6)+i*440,1460)-90,220+sin(ui_time*1.1+i)*35)
		var flap=sin(ui_time*13+i)*7
		draw_colored_polygon(PackedVector2Array([pos+Vector2(-13,flap),pos+Vector2(-6,-3),pos,pos+Vector2(6,-3),pos+Vector2(13,flap),pos+Vector2(5,4),pos+Vector2(-5,4)]),Color(.11,.07,.20,.55))

func ground(offset: float=0) -> void:
	draw_rect(Rect2(0,HordeRun.FLOOR,1280,146),Color("21182f"))
	draw_rect(Rect2(0,HordeRun.FLOOR,1280,9),Color("6a7772"))
	draw_rect(Rect2(0,HordeRun.FLOOR+9,1280,9),Color("374545"))
	for i in range(38):
		var x=fposmod(i*39-offset,1450)-75
		draw_rect(Rect2(x,HordeRun.FLOOR+2,34,5),Color("8b9383"))
		draw_line(Vector2(x+3,HordeRun.FLOOR+16),Vector2(x+31,HordeRun.FLOOR+16),Color("243b3c"),2,true)
		var y=612+posmod(i*17,81)
		draw_line(Vector2(x,y),Vector2(x+13,y+4),Color("3a2b4a"),3,true)
		if i%3==0:
			var sway=sin(ui_time*2.8+i)*2
			var base=Vector2(x+12,HordeRun.FLOOR+1)
			draw_line(base,base+Vector2(-5+sway,-9),Color("718779"),2,true)
			draw_line(base,base+Vector2(2+sway,-13),Color("809883"),2,true)
			draw_line(base,base+Vector2(7+sway,-7),Color("5f8176"),2,true)

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
		"worlds": draw_worlds()
		"missions": draw_missions()
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
	actor.paint(self,1,Vector2(190,620),160,ui_time*2.5,"run",ui_time)
	actor.paint(self,int(data.skin),Vector2(368,625),210,ui_time*2.5+.3,"run",ui_time)
	actor.paint(self,2,Vector2(591,622),173,ui_time*2.5+.7,"run",ui_time)
	button(Rect2(862,218,343,80),"JOGAR","play",Color("d9974c"),-2,38)
	button(Rect2(862,316,343,60),"MELHORIAS","shop",Color("8054a7"),0,25)
	button(Rect2(862,389,343,60),"MONSTROS","monsters",Color("487385"),11,25)
	button(Rect2(862,462,343,60),"CENÁRIOS","worlds",Color("596d83"),10,25)
	button(Rect2(862,535,343,60),"MISSÕES","missions",Color("6a5789"),1,25)
	button(Rect2(862,608,343,55),"COMO JOGAR","help",Color("4d7468"),4,22)
	panel(Rect2(78,652,650,44),Color(.10,.06,.17,.83),Color("6e5466"),18)
	text("RECORDE  "+str(data.best)+" m",Vector2(102,682),19,GOLD,true)
	text("ALPHA 0.3",Vector2(610,682),14,Color("bbaac8"),true)

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
		else: floating_item(item.icon,Vector2(x+139,280+sin(ui_time*2+i)*4),124)
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
	text("COLEÇÃO DE MONSTROS",Vector2(67,98),41,GOLD,true,false,5)
	text("Compre visuais para o líder. Os bônus da pista continuam disponíveis.",Vector2(70,139),19,CREAM)
	currency()
	var notes=["Seu primeiro companheiro.","Um novo líder para a horda.","A máscara da pista ativa sua força.","O cristal da pista permite voar."]
	for i in range(4):
		var x=64+i*291
		var monster=MonsterCatalog.MONSTERS[i]
		var owned=i in data.owned
		var equipped=int(data.skin)==i
		panel(Rect2(x,177,278,450),Color(.18,.11,.25,.94),MINT if equipped else Color("76527d"),22,3)
		if owned:
			actor.paint(self,i,Vector2(x+139,390),164,ui_time*2.5,"fly" if i==3 else "run",ui_time)
		else:
			actor.paint(self,i,Vector2(x+139,390),164,ui_time*1.7,"idle",ui_time,0,Color(.07,.04,.12,1))
			text("?",Vector2(x+139,338),49,Color("bba4ce"),true,true,3)
		text(monster.name.to_upper(),Vector2(x+139,434),20,monster.color,true,true,2)
		text("VISUAL DO LÍDER",Vector2(x+139,464),13,CREAM,true,true)
		wrapped(notes[i],Vector2(x+24,501),230,17,Color("d9cce3"),2)
		var label="EM USO" if equipped else ("USAR" if owned else str(MonsterCatalog.SKIN_PRICES[i])+" MOEDAS")
		button(Rect2(x+16,554,246,54),label,"skin_"+str(i),Color("557d70") if equipped else Color("8054a7"),-2,20)
	button(Rect2(68,652,218,49),"VOLTAR","back",Color("513c67"),-2,20)
	text("Skins mudam o visual; transformações dão poderes temporários.",Vector2(319,683),16,MINT)

func draw_help() -> void:
	text("COMO JOGAR",Vector2(68,105),44,GOLD,true,false,5)
	var headings=["1. PULE E RECRUTE","2. VIRE VEÍCULOS","3. USE OS PODERES"]
	var descriptions=["Toque para pular, segure para ir mais alto. Evite buracos, bombas e tiros! Quem cai é perdido. A última criatura perdida encerra a fuga.","Criaturas no chão: moto 2, carro 4, ônibus 8, caminhão 10, tanque 12 e avião 16. Vire para ganhar moedas e recrutas; com menos força, pule!","Mosca sobe sozinha. Segure para descer e coletar; solte para subir. Mascarado quebra obstáculos, mas cai nos buracos. Poção acelera e dobra moedas."]
	for i in range(3):
		var x=68+i*392
		panel(Rect2(x,187,364,414),Color(.18,.11,.26,.94),Color("76527d"),22,3)
		if i==1: floating_item(7,Vector2(x+182,278),83)
		else: floating_item(4 if i==0 else 0,Vector2(x+182,272),103)
		text(headings[i],Vector2(x+182,376),22,GOLD,true,true,2)
		wrapped(descriptions[i],Vector2(x+27,411),310,17,CREAM,7)
	button(Rect2(68,633,240,66),"VOLTAR","back",Color("513c67"),-2,23)
	text("Espaço pula/mergulha; Esc pausa. Salto duplo: Pulo Ágil nível 2.",Vector2(350,672),17,MINT)

func draw_run() -> void:
	ground(runner.world_px)
	effects.draw_trails(self,actor,runner.elapsed)
	# Draw holes before objects so foreground enemies cannot disappear behind them.
	for e in runner.entities:
		if e.kind!="gap" or e.x< -400 or e.x>1400: continue
		draw_rect(Rect2(e.x,HordeRun.FLOOR,e.width,146),Color("080616"))
		for edge in [e.x,e.x+e.width]:
			draw_line(Vector2(edge,HordeRun.FLOOR+4),Vector2(edge,HordeRun.FLOOR+137),Color("68466e"),4,true)
		if e.x>HordeRun.ANCHOR: text("PULO!",Vector2(e.x+e.width*.5,HordeRun.FLOOR-28),19,CORAL,true,true,3)
	for e in runner.entities:
		if e.taken or e.x< -200 or e.x>1500: continue
		var bob=sin(ui_time*4+e.bob)*5
		if MonsterCatalog.VEHICLES.has(e.kind):
			draw_vehicle(e)
			continue
		match e.kind:
			"coin": floating_item(1,Vector2(e.x,e.y+bob),33)
			"recruit":
				draw_circle(Vector2(e.x,e.y-43),47,Color(.55,1,.73,.065+.025*sin(ui_time*3)))
				creature(e.variant,0,Vector2(e.x,e.y),104,true)
				text("+1",Vector2(e.x,e.y-116),19,MINT,true,true,2)
			"crystal","mask","shield","boost":
				var icon=0 if e.kind=="crystal" else (11 if e.kind=="mask" else (2 if e.kind=="shield" else 5))
				var centre=Vector2(e.x,e.y+bob)
				var color=GOLD if e.kind=="boost" else Color("c39cf3")
				draw_circle(centre,51+sin(ui_time*4)*4,Color(color.r,color.g,color.b,.08))
				draw_circle(centre,36,Color(color.r,color.g,color.b,.12))
				for i in range(3):
					var angle=ui_time*2.8+i*TAU/3
					draw_circle(centre+Vector2(cos(angle)*43,sin(angle)*30),3,color)
				floating_item(icon,centre,70*(1+sin(ui_time*3)*.04))
				text("FRENESI" if e.kind=="boost" else "BÔNUS",centre+Vector2(0,-57),13,color,true,true,2)
			"crate": item_sprite(6,Vector2(e.x,e.y-36),72)
			"spikes": item_sprite(8,Vector2(e.x,e.y-24),48)
			"bomb":
				var point=Vector2(e.x,e.y-31)
				scenery.sprite(self,art.props[0],point,64,Color.WHITE,sin(ui_time*7+e.bob)*.07)
				scenery.flame(self,point+Vector2(9,-29),ui_time+e.bob,7)
				draw_arc(point,42,0,TAU,24,Color(1,.48,.30,.16+.10*sin(ui_time*9)),2,true)
			"soldier":
				actor.paint(self,5,Vector2(e.x,e.y),108,0,"aim",ui_time,0,Color.WHITE,true)
				var muzzle=Vector2(e.x-54,e.y-64)
				if e.flash>0: scenery.sprite(self,art.props[5],muzzle,28)
				if e.x>HordeRun.ANCHOR+230:
					text("TIRO!" if e.timer<.65 else "EXÉRCITO",Vector2(e.x,e.y-130),15,CORAL,true,true,2)
					if e.timer<.65: draw_line(muzzle,muzzle+Vector2(-120,0),Color(1,.40,.26,.18),2,true)
			"bullet":
				draw_line(Vector2(e.x+31,e.y),Vector2(e.x,e.y),Color(1,.62,.22,.45),4,true)
				draw_circle(Vector2(e.x,e.y),4,GOLD)
			"helicopter":
				scenery.helicopter(self,Vector2(e.x,e.y+sin(ui_time*3+e.bob)*5),92,ui_time,sin(ui_time*2)*.06)
				text("SALTE!",Vector2(e.x,e.y-76),16,CORAL,true,true,2)
	for i in range(runner.members.size()-1,-1,-1):
		var member=runner.members[i]
		var kind=int(member.get("death_kind",member.kind)) if member.falling else (runner.perk_kind if runner.perk_left>0 else int(member.kind))
		var state=animation_state(member)
		var foot=Vector2(runner.member_x(i),member.y-int(i/8)*12)
		if state=="fly": foot.y+=sin(runner.elapsed*7+i)*3
		var height=112.0*(1+sin(member.arrival/.35*PI)*.10)
		var phase=runner.world_px/84.0+i*.17
		if not member.falling:
			var shadow_size=clampf(1-(HordeRun.FLOOR-member.y)/420,.25,1)
			draw_set_transform(Vector2(foot.x,HordeRun.FLOOR+4),0,Vector2(23*shadow_size,4*shadow_size))
			draw_circle(Vector2.ZERO,1,Color(.02,.01,.05,.28*shadow_size))
			draw_set_transform(Vector2.ZERO)
			if runner.shields>0: draw_arc(foot-Vector2(0,56),62,0,TAU,32,Color(.5,.9,1,.4),3,true)
		var blink=Color(1,1,1,.45) if runner.hit_grace>0 and int(ui_time*14)%2==0 else Color.WHITE
		actor.paint(self,kind,foot,height,phase,state,runner.elapsed+i*.071,float(member.land_left),blink)
	effects.paint(self,art,actor)
	scenery.paint_front(self,runner)

func draw_run_hud() -> void:
	panel(Rect2(28,24,214,88),Color(.12,.07,.19,.91),Color("776077"),20)
	text("FUGA",Vector2(49,54),15,MINT,true)
	text(str(runner.distance())+" m",Vector2(48,94),29,CREAM,true,false,2)
	panel(Rect2(259,24,197,88),Color(.12,.07,.19,.91),Color("776077"),20)
	text("HORDA",Vector2(280,54),15,MINT,true)
	text(str(runner.active_count())+" CRIATURAS",Vector2(280,94),20,CREAM,true)
	panel(Rect2(473,24,189,88),Color(.12,.07,.19,.91),Color("776077"),20)
	item_sprite(1,Vector2(511,68),42)
	text(str(runner.coins),Vector2(545,83),28,GOLD,true,false,2)
	if runner.perk_left>0 or runner.boost_left>0:
		panel(Rect2(679,24,345,88),Color(.20,.10,.29,.94),Color("be99df"),20)
		floating_item((0 if runner.perk_kind==3 else 11) if runner.perk_left>0 else 5,Vector2(714,68),46)
		text(("MOSCA MUTANTE" if runner.perk_kind==3 else "MASCARADOS") if runner.perk_left>0 else "FRENESI",Vector2(749,57),19,MINT,true)
		text(str(ceili(runner.perk_left if runner.perk_left>0 else runner.boost_left))+" segundos",Vector2(749,88),20,CREAM)
		var duration=(7.0 if runner.perk_kind==3 else 9.0)+int(data.levels.perk)*2 if runner.perk_left>0 else 5.0
		draw_rect(Rect2(749,99,248*(runner.perk_left if runner.perk_left>0 else runner.boost_left)/duration,4),MINT)
	button(Rect2(1160,28,83,73),"II","pause",Color("513565"),-2,27)
	text(MonsterCatalog.AREAS[runner.area()].name.to_upper()+"  •  TÚNEL "+str(runner.tunnel_number()),Vector2(32,148),16,MonsterCatalog.AREAS[runner.area()].color,true,false,2)
	if runner.inside_tunnel(): text("ATRAVESSANDO O TÚNEL",Vector2(640,211),23,GOLD,true,true,3)
	elif runner.recovery_left>0: text("REAGRUPE!",Vector2(33,178),14,MINT,true,false,2)
	elif runner.pressure>.6: text("A HORDA CHAMOU ATENÇÃO!",Vector2(33,178),14,CORAL,true,false,2)
	button(Rect2(1053,578,190,107),"MERGULHAR" if runner.perk_kind==3 and runner.perk_left>0 else "PULAR","jump",Color("8753aa"),-2,26)
	if runner.perk_kind==3 and runner.perk_left>0:
		text("SEGURE PARA DESCER • SOLTE PARA SUBIR",Vector2(687,671),15,MINT,true,true,2)
	elif runner.world_px<1800:
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
	draw_rect(Rect2(0,0,1280,720),Color(.035,.012,.07,.78))
	panel(Rect2(224,137,832,450),Color(.18,.10,.25,.97),Color("b79ac0"),28,4)
	scenery.sprite(self,art.props[4],Vector2(640,126+sin(ui_time*2.8)*3),132)
	text("FIM DA HORDA",Vector2(640,245),45,GOLD,true,true,5)
	text("Sua horda descansa. As melhorias ficam.",Vector2(640,282),20,CREAM,false,true)
	text(str(runner.distance())+" m",Vector2(640,354),55,CREAM,true,true,4)
	text("RECORDE  "+str(data.best)+" m",Vector2(640,393),18,MINT,true,true)
	var values=["+"+str(runner.coins),str(runner.recruits),str(runner.cars),str(runner.tunnel_number())]
	var labels=["MOEDAS","RECRUTAS","VEÍCULOS","TÚNEIS"]
	for i in range(4):
		var x=261+i*194
		panel(Rect2(x,416,178,91),Color("291b36"),Color("5f456f"),16,1,false)
		text(values[i],Vector2(x+89,455),26,GOLD,true,true,2)
		text(labels[i],Vector2(x+89,485),14,MINT,true,true)
	text("CARTEIRA: "+str(data.wallet)+" moedas  •  Suas compras continuam com você",Vector2(640,547),19,Color("d4c2e1"),false,true)
	button(Rect2(224,613,228,73),"MENU","home",Color("5d426f"),-2,25)
	button(Rect2(474,613,285,73),"MELHORIAS","shop",Color("845eaa"),-2,25)
	button(Rect2(781,613,275,73),"DE NOVO","play",Color("c78a4b"),-2,27)

func validate_save(value) -> Dictionary:
	if not value is Dictionary or int(value.get("version",0)) not in [1,2,3]: return MonsterCatalog.defaults()
	var result=MonsterCatalog.defaults()
	result.wallet=clampi(int(value.get("wallet",120)),0,9999999)
	result.best=clampi(int(value.get("best",0)),0,9999999)
	result.runs=maxi(0,int(value.get("runs",0)))
	result.audio=bool(value.get("audio",true))
	var areas=value.get("areas",[])
	if areas is Array:
		for area in areas:
			if int(area) in [2,3] and int(area) not in result.areas: result.areas.append(int(area))
	var raw_levels=value.get("levels",{})
	if raw_levels is Dictionary:
		for item in MonsterCatalog.UPGRADES: result.levels[item.id]=clampi(int(raw_levels.get(item.id,0)),0,int(item.max))
	var owned=value.get("owned",[])
	if owned is Array:
		for kind in owned:
			if int(kind) in [1,2,3] and int(kind) not in result.owned: result.owned.append(int(kind))
	var skin=int(value.get("skin",0))
	result.skin=skin if skin in result.owned else 0
	result.mission_tier=clampi(int(value.get("mission_tier",0)),0,9999)
	result.missions_completed=clampi(int(value.get("missions_completed",0)),0,99999)
	var claimed=value.get("claimed",[])
	if int(value.get("version",0))==1:
		if claimed is Array:
			for challenge in MonsterCatalog.CHALLENGES:
				if challenge.id in claimed: result.claimed.append("0:"+str(challenge.id))
			result.missions_completed=result.claimed.size()
			if result.claimed.size()==3: result.mission_tier=1;result.claimed.clear()
	else:
		var progress=value.get("mission_progress",{})
		for challenge in MonsterCatalog.active_missions(result.mission_tier):
			if claimed is Array and challenge.key in claimed: result.claimed.append(challenge.key)
			if progress is Dictionary: result.mission_progress[challenge.id]=clampi(int(progress.get(challenge.id,0)),0,int(challenge.target))
			if challenge.key in result.claimed: result.mission_progress[challenge.id]=int(challenge.target)
	return result

func read_save(path: String=SAVE_PATH) -> Dictionary:
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and int(parsed.get("version",0)) in [1,2,3]: return validate_save(parsed)
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
	if not path.contains("/frame-"): print("HORDE_CAPTURE "+path)

func capture_preview() -> void:
	await get_tree().create_timer(.5).timeout
	var path=OS.get_environment("HORDE_CAPTURE_PATH")
	if path.is_empty(): path="user://NoiteDaHorda-menu.png"
	var base=path.get_basename().trim_suffix("-menu")
	await capture_frame(base+"-menu.png")
	perform_action("shop");await capture_frame(base+"-shop.png")
	perform_action("monsters");await capture_frame(base+"-monsters.png")
	perform_action("worlds");await capture_frame(base+"-worlds.png")
	start_run();capture_freeze=true
	runner.entities.clear();runner.next_segment=99999
	runner.add_member(1);runner.add_member(0)
	runner.add_entity("crate",830)
	runner.add_entity("car",1190)
	for i in range(6): runner.add_entity("coin",600+i*74,HordeRun.FLOOR-130)
	runner.add_entity("crystal",1030,HordeRun.FLOOR-92)
	runner.world_px=1100;runner.jump()
	for i in range(11): runner.advance(1.0/60,true)
	consume_run_events();update_run_visuals(.18)
	await capture_frame(base+"-run.png")
	runner.grant_perk(3);consume_run_events()
	for i in range(70): runner.advance(1.0/60,false);update_run_visuals(1.0/60)
	consume_run_events();toast_left=0
	await capture_frame(base+"-perk.png")
	runner.world_px=5510;runner.entities.clear();effects.clear();scenery.update(.1,runner)
	await capture_frame(base+"-tunnel.png")
	runner.world_px=7220;runner.perk_left=0;runner.perk_kind=-1
	runner.entities.clear()
	for member in runner.members: member.y=HordeRun.FLOOR;member.vy=0
	for i in range(4): runner.add_member(i%2)
	runner.add_entity("bus",1110);runner.add_entity("bomb",715)
	runner.add_entity("soldier",910);runner.add_entity("helicopter",580,HordeRun.FLOOR-67)
	for i in range(5): runner.add_entity("coin",590+i*82,HordeRun.FLOOR-175)
	scenery.update(.1,runner);scenery.crash_age=1.45;toast_left=0
	await capture_frame(base+"-city.png")
	runner.entities.clear();runner.world_px=15220;runner.route.assign([0,1,2,3])
	scenery.update(.1,runner)
	runner.add_entity("tank",760);runner.add_entity("truck",1080)
	await capture_frame(base+"-industrial.png")
	runner.world_px=21220;runner.entities.clear();scenery.update(.1,runner)
	runner.add_entity("plane",1030);runner.add_entity("moto",670)
	await capture_frame(base+"-airport.png")
	# Game-over screenshot comes from a real fatal pit, not a decorative mockup.
	runner.entities.clear();runner.perk_left=0;runner.perk_kind=-1
	runner.add_entity("gap",HordeRun.ANCHOR-270,HordeRun.FLOOR,0,650)
	for i in range(90): runner.advance(1.0/60)
	consume_run_events();update_run_visuals(.2);toast_left=0;end_delay=-1
	change_screen("results")
	await capture_frame(base+"-gameover.png")
	print("HORDE_CAPTURE_OK: eleven real game screens")
	get_tree().quit()

func animation_state(member: Dictionary) -> String:
	if member.falling: return "fall"
	if runner.perk_kind==3 and runner.perk_left>0: return "fly"
	if member.y<HordeRun.FLOOR-4: return "rise" if member.vy<0 else "fall"
	return "run"

func update_run_visuals(dt: float) -> void:
	effects.update(dt,0 if runner.dead else runner.speed)
	if not runner.dead:
		scenery.update(dt,runner)
		for event in scenery.events:
			sound.play("city_scream" if event=="background_scream" else "explosion",-23)
		scenery.events.clear()
		voice_tick-=dt
		if voice_tick<=0 and runner.active_count()>0:
			var lead=runner.leader_index()
			sound.play_monster(runner.perk_kind if runner.perk_left>0 else int(runner.members[lead].kind))
			voice_tick=4.5
	trail_tick+=dt
	if not runner.members.is_empty() and not runner.dead and trail_tick>=.09:
		trail_tick=0
		var index=runner.members.size()-1
		var m=runner.members[index]
		if not m.falling and (runner.boost_left>0 or runner.speed>=380):
			var foot=Vector2(runner.member_x(index),m.y-int(index/8)*12)
			effects.ghost(runner.perk_kind if runner.perk_left>0 else int(m.kind),foot,runner.world_px/84+index*.17,animation_state(m),m.land_left)
			for i in range(2):
				effects.add("speed",foot+Vector2(-22,randf_range(-75,-15)),Vector2(-100,0),MINT,randf_range(20,43),.22)

func floating_item(index: int,centre: Vector2,height: float,modulate: Color=Color.WHITE,lantern: bool=false) -> void:
	var texture=art.items[index]
	var size=texture.get_size()*(height/texture.get_height())
	var squash=maxf(.25,absf(cos(ui_time*3.8+centre.x*.003))) if index==1 else 1.0
	draw_set_transform(centre,sin(ui_time*2.5+centre.x*.003)*(.035 if lantern else .09),Vector2(squash,1))
	draw_texture_rect(texture,Rect2(-size*.5,size),false,modulate)
	draw_set_transform(Vector2.ZERO)

func buy_skin(index: int) -> bool:
	if index<0 or index>=4: return false
	if index not in data.owned:
		var cost=int(MonsterCatalog.SKIN_PRICES[index])
		if int(data.wallet)<cost:
			show_toast("Faltam "+str(cost-int(data.wallet))+" moedas para este monstro.")
			return false
		data.wallet-=cost;data.owned.append(index);sound.play("buy")
	data.skin=index
	show_toast(MonsterCatalog.MONSTERS[index].name+" escolhido como líder!",2)
	save_game()
	return true

func draw_missions() -> void:
	text("MISSÕES DA MADRUGADA",Vector2(67,101),40,GOLD,true,false,5)
	text("Capítulo "+str(int(data.mission_tier)+1)+" • Complete o trio para receber novos desafios.",Vector2(70,144),20,CREAM)
	currency()
	var missions=MonsterCatalog.active_missions(int(data.mission_tier))
	for i in range(3):
		var item=missions[i]
		var x=68+i*392
		var progress=int(data.mission_progress.get(item.id,0))
		var done=item.key in data.claimed
		panel(Rect2(x,195,362,385),Color(.18,.11,.26,.94),MINT if done else Color("76527d"),22,3)
		floating_item(7 if item.stat=="cars" else (0 if item.stat in ["flights","bonuses"] else 1),Vector2(x+181,279),82)
		text(item.title,Vector2(x+181,378),18,GOLD,true,true,2)
		text("CONCLUÍDA" if done else str(progress)+" / "+str(item.target),Vector2(x+181,429),27,MINT if done else CREAM,true,true)
		panel(Rect2(x+34,455,294,13),Color("21152f"),Color("21152f"),6,0,false)
		panel(Rect2(x+34,455,maxf(8,294*float(progress)/float(item.target)),13),MINT,Color("629d83"),6,0,false)
		text("RECOMPENSA: "+str(item.reward)+" MOEDAS",Vector2(x+181,521),18,GOLD,true,true)
	button(Rect2(68,632,240,66),"VOLTAR","back",Color("513c67"),-2,23)
	text("O progresso fica salvo entre as corridas.",Vector2(350,671),20,MINT)

func motion_preview() -> void:
	await get_tree().create_timer(.3).timeout
	var folder=OS.get_environment("HORDE_MOTION_PATH")
	if folder.is_empty(): folder="user://motion"
	DirAccess.make_dir_recursive_absolute(folder)
	var first_frame=maxi(0,int(OS.get_environment("HORDE_MOTION_START")))
	data=MonsterCatalog.defaults();data.levels.horde=3
	start_run();capture_freeze=true
	runner.entities.clear();runner.next_segment=99999
	for i in range(8): runner.add_entity("coin",700+i*85,HordeRun.FLOOR-80)
	for frame in range(480):
		ui_time=float(frame)/30.0
		if frame==15: runner.jump()
		if frame==55: runner.add_entity("car",HordeRun.ANCHOR+320)
		if frame==80: runner.world_px=5100
		if frame==90: runner.grant_perk(3)
		if frame==230: runner.perk_left=.01
		if frame==250:
			runner.entities.clear()
			while runner.active_count()<16: runner.add_member(runner.active_count()%2,false)
			runner.add_entity("plane",HordeRun.ANCHOR+420)
		if frame==300:
			var soldier=runner.add_entity("soldier",HordeRun.ANCHOR+620);soldier.timer=.18
			runner.add_entity("helicopter",980,HordeRun.FLOOR-65)
			runner.add_entity("bomb",1140)
		if frame==328: runner.jump()
		if frame==360:
			# A second staged scenario proves real mixed-horde pit death and retry UI.
			start_run();capture_freeze=true;runner.entities.clear();runner.next_segment=99999
			runner.world_px=7220
			for i in range(runner.members.size()): runner.members[i].kind=i
			runner.add_entity("gap",HordeRun.ANCHOR+220,HordeRun.FLOOR,0,420)
			show_toast("QUEDAS ELIMINAM CADA CRIATURA",1.3)
		var held=(frame>=15 and frame<24) or (frame>=155 and frame<210) or (frame>=328 and frame<338)
		if screen=="run":
			runner.advance(1.0/60.0,held);runner.advance(1.0/60.0,held)
			consume_run_events();update_run_visuals(1.0/30.0)
			if end_delay>=0:
				end_delay-=1.0/30
				if end_delay<0: change_screen("results")
		toast_left=maxf(0,toast_left-1.0/30.0)
		flash=maxf(0,flash-1.0/30.0*1.7);shake=maxf(0,shake-1.0/30.0*20)
		if frame>=first_frame: await capture_frame(folder+"/frame-%04d.png"%frame)
	print("HORDE_MOTION_OK: 480 real rendered frames; staged course snapshots and simulated touch; final pit game over")
	get_tree().quit()

func draw_vehicle(entity: Dictionary) -> void:
	var spec=MonsterCatalog.VEHICLES[entity.kind]
	var point=Vector2(entity.x,entity.y-float(spec.height)*.5)
	scenery.sprite(self,art.vehicle(entity.kind),point,float(spec.height),Color.WHITE,sin(ui_time*3+entity.bob)*.009)
	if entity.kind=="plane":
		for x in [-40,30]:
			draw_line(point+Vector2(x,-12-sin(ui_time*60)*23),point+Vector2(x,-12+sin(ui_time*60)*23),Color(.9,.94,1,.72),3,true)
	if entity.kind=="tank":
		for i in range(4):
			var x=fposmod(ui_time*28+i*27,108)-54
			draw_line(point+Vector2(x,43),point+Vector2(x+8,43),Color(.84,.86,.62,.5),2,true)
	var capable=runner.grounded_strength()>=int(spec.need) or (runner.perk_kind==2 and runner.perk_left>0)
	var color=MINT if capable else CORAL
	panel(Rect2(entity.x-57,entity.y-float(spec.height)-47,114,34),Color(.13,.08,.19,.94),color,12,2,false)
	text("VIRAR: "+str(spec.need),Vector2(entity.x,entity.y-float(spec.height)-23),15,color,true,true,1)

func buy_area(index: int) -> bool:
	if index<0 or index>=MonsterCatalog.AREAS.size(): return false
	if index in data.areas:
		show_toast("Este cenário já está na sua rota.",1.7);return true
	var cost=int(MonsterCatalog.AREAS[index].price)
	if int(data.wallet)<cost:
		show_toast("Faltam "+str(cost-int(data.wallet))+" moedas para este cenário.");return false
	data.wallet-=cost;data.areas.append(index);sound.play("buy")
	show_toast(MonsterCatalog.AREAS[index].name+" entra na próxima fuga!",2.3)
	save_game();return true

func draw_worlds() -> void:
	text("CENÁRIOS DA FUGA",Vector2(67,101),42,GOLD,true,false,5)
	text("Cada túnel leva à próxima região. Dois cenários já vêm liberados!",Vector2(70,144),20,CREAM)
	currency()
	var notes=["Névoa, lanternas e criaturas à espera.","Fogo, civis fugindo e helicópteros caindo.","Fábricas, fumaça e máquinas de guerra.","Pista iluminada, hangares e aviões."]
	for i in range(4):
		var x=64+i*291
		var area=MonsterCatalog.AREAS[i]
		var owned=i in data.areas
		panel(Rect2(x,186,278,430),Color(.18,.11,.25,.94),area.color if owned else Color("76527d"),22,3)
		draw_rect(Rect2(x+12,202,254,191),Color("38264c"))
		draw_texture_rect(art.world_thumbnails[i],Rect2(x+12,205,254,188),false,Color.WHITE if owned else Color(.55,.49,.63,1))
		text(area.name.to_upper(),Vector2(x+139,434),18,area.color,true,true,2)
		wrapped(notes[i],Vector2(x+24,474),230,17,Color("ded0e7"),3)
		button(Rect2(x+16,551,246,52),"NA SUA ROTA" if owned else str(area.price)+" MOEDAS","area_"+str(i),Color("557d70") if owned else Color("8054a7"),-2,19)
	button(Rect2(68,650,218,49),"VOLTAR","back",Color("513c67"),-2,20)
	text("A rota começa no cemitério. Novas regiões entram após a cidade.",Vector2(319,682),17,MINT)
