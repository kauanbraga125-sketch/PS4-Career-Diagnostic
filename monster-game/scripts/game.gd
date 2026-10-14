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
var reward_rng=RandomNumberGenerator.new()
var run_settled=false
var run_report: Dictionary={}
var result_time=0.0
var result_level=1
var ritual_view: Dictionary={}
var ritual_time=4.0
var ritual_particle_tick=0.0
var ritual_reward_played=false
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
	reward_rng.randomize()
	test_mode="--self-test" in OS.get_cmdline_user_args()
	capture_mode="--capture" in OS.get_cmdline_user_args() or "--motion-preview" in OS.get_cmdline_user_args()
	if not test_mode and not capture_mode: data=read_save()
	sound=HordeSound.new()
	add_child(sound)
	sound.set_enabled(bool(data.audio))
	sound.set_music("moon_menu")
	if not test_mode and not capture_mode and int(data.active_souls)>0:
		HordeProgress.settle(data,int(data.active_souls),reward_rng);save_game()
	if not test_mode and not capture_mode: begin_ritual()
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
	if screen in ["home","results"]: update_rewards(dt)
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
	if next=="home": begin_ritual()
	if next=="results": result_time=0;result_level=int(run_report.get("old_level",data.player_level))
	screen=next
	buttons.clear()
	pressed_button=""
	jump_touches.clear()
	jump_held=false
	sound.set_music("midnight_run" if next in ["run","pause"] else "moon_menu")
	sound.set_area(runner.area(),next=="run" and not runner.dead)
	queue_redraw()

func start_run() -> void:
	run_settled=false;run_report={};data.active_souls=0
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
			"capture":
				sound.play_monster(int(e.kind));effects.capture(point,int(e.kind))
			"soul":
				sound.play("soul_capture",-13);effects.capture(point,int(e.kind))
				effects.soul(point,Vector2(411,73));data.active_souls=runner.souls
				save_game()
			"contact": sound.play("land",-18);effects.dust(point,4,.7)
			"weak_vehicle": show_toast("FALTOU FORÇA: "+str(e.count)+" / "+str(e.need),1.8)
			"tunnel_enter": sound.play("tunnel",-18)
			"tunnel_exit": sound.play("tunnel",-18)
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
				show_toast("MOSCA: SEGURE PARA DESCER, SOLTE PARA SUBIR" if e.kind==3 else "MASCARADOS! PROTEÇÃO CONTRA IMPACTOS",2.4)
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
				effects.smash(point,object_kind,float(e.get("tilt",0)))
				if MonsterCatalog.VEHICLES.has(object_kind): show_toast("VEÍCULO VIRADO! +"+str(MonsterCatalog.VEHICLES[object_kind].rescues)+" CIVIS LIBERTADOS",1.7)
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
	if run_settled or end_delay>=0 or screen not in ["run","pause"]: return
	data.best=maxi(int(data.best),runner.distance())
	data.runs+=1
	run_settled=true
	run_report=HordeProgress.settle(data,runner.souls,reward_rng)
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
			HordeProgress.queue_mission(data,challenge)
			data.missions_completed+=1
			run_challenges.append(challenge.title)
			sound.play("challenge")
			show_toast("MISSÃO CONCLUÍDA  +"+str(challenge.ritual)+" PARA O RITUAL",2.5)
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
		"credits": change_screen("credits")
		"retry":
			if screen in ["run","pause"] and not runner.dead: runner.finish();consume_run_events()
			end_delay=-1;start_run()
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
		"credits": draw_credits()
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
	text("NOITE",Vector2(82,118),72,CREAM,true,false,8)
	text("DA HORDA",Vector2(82,188),64,GOLD,true,false,8)
	text("Capture civis. Reúna almas. Desperte o ritual.",Vector2(88,224),22,MINT,false,false,2)
	panel(Rect2(78,250,650,78),Color(.12,.07,.20,.93),Color("9c83b6"),18)
	text("JOGADOR NÍVEL "+str(data.player_level),Vector2(99,284),20,GOLD,true)
	text(str(data.level_souls)+" / "+str(HordeProgress.level_target(int(data.player_level)))+" ALMAS",Vector2(491,284),17,MINT,true)
	progress_bar(Rect2(100,301,603,10),float(data.level_souls)/HordeProgress.level_target(int(data.player_level)),MINT)
	draw_ritual_panel()
	actor.paint(self,1,Vector2(183,630),121,ui_time*2.8,"run",ui_time)
	actor.paint(self,int(data.skin),Vector2(370,637),158,ui_time*2.8+.3,"run",ui_time)
	actor.paint(self,2,Vector2(583,633),130,ui_time*2.8+.7,"run",ui_time)
	button(Rect2(862,218,343,80),"JOGAR","play",Color("d9974c"),-2,38)
	button(Rect2(862,316,343,60),"MELHORIAS","shop",Color("8054a7"),0,25)
	button(Rect2(862,389,343,60),"MONSTROS","monsters",Color("487385"),11,25)
	button(Rect2(862,462,343,60),"CENÁRIOS","worlds",Color("596d83"),10,25)
	button(Rect2(862,535,343,60),"MISSÕES","missions",Color("6a5789"),1,25)
	button(Rect2(862,608,343,55),"COMO JOGAR","help",Color("4d7468"),4,22)
	panel(Rect2(78,656,650,40),Color(.10,.06,.17,.88),Color("6e5466"),15)
	text("RECORDE: "+str(data.best_souls)+" ALMAS  •  "+str(data.best)+" m",Vector2(98,682),18,GOLD,true)
	text("ALPHA 0.4",Vector2(610,682),14,Color("bbaac8"),true)
	effects.paint(self,art,actor)

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
	var headings=["1. CAPTURE CIVIS","2. VIRE VEÍCULOS","3. USE OS PODERES"]
	var descriptions=["Capture civis após a animação de cada monstro. Cada civil rende uma alma. Toque para pular e evite buracos, bombas e tiros.","Criaturas no chão: moto 2, carro 4, ônibus 8, caminhão 10, tanque 12 e avião 16. Cada criatura precisa encostar! A contagem aumenta até virar e libertar passageiros. Com menos força, salte para evitar o impacto.","Mosca sobe sozinha. Segure para descer e coletar; solte para subir. Mascarado quebra pequenas ameaças e protege de impactos, mas cai nos buracos. Poção acelera e dobra moedas."]
	for i in range(3):
		var x=68+i*392
		panel(Rect2(x,187,364,414),Color(.18,.11,.26,.94),Color("76527d"),22,3)
		if i==1: floating_item(7,Vector2(x+182,278),83)
		else: floating_item(4 if i==0 else 0,Vector2(x+182,272),103)
		text(headings[i],Vector2(x+182,376),22,GOLD,true,true,2)
		wrapped(descriptions[i],Vector2(x+27,411),310,17,CREAM,7)
	button(Rect2(68,633,240,66),"VOLTAR","back",Color("513c67"),-2,23)
	button(Rect2(349,633,230,66),"CRÉDITOS","credits",Color("4d7468"),-2,22)
	text("Espaço pula/mergulha; Esc pausa.",Vector2(620,674),18,MINT)

func draw_run() -> void:
	ground(runner.world_px)
	scenery.paint_front(self,runner)
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
		if e.kind in ["civilian","soldier"] and e.state=="capture": continue
		var bob=sin(ui_time*4+e.bob)*5
		if MonsterCatalog.VEHICLES.has(e.kind):
			draw_vehicle(e)
			continue
		match e.kind:
			"coin": floating_item(1,Vector2(e.x,e.y+bob),33)
			"civilian": draw_civilian(e)
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
			"bomb","air_bomb":
				var aerial=e.kind=="air_bomb"
				var point=Vector2(e.x,e.y if aerial else e.y-39)
				scenery.sprite(self,art.ritual[3] if aerial else art.props[0],point,86 if aerial else 78,Color.WHITE,sin(ui_time*7+e.bob)*.07)
				draw_fuse(point+Vector2(10,-36 if aerial else -37),ui_time+e.bob)
				if aerial: text("PULE" if e.y>HordeRun.FLOOR-130 else "POR BAIXO",point+Vector2(0,-72),15,CORAL,true,true,2)
			"soldier":
				if e.state=="capture": draw_civilian(e)
				else:
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
				scenery.helicopter(self,Vector2(e.x,e.y),185,ui_time,sin(ui_time*2)*.06)
				text("PULE!" if e.y>HordeRun.FLOOR-180 else "POR BAIXO",Vector2(e.x,e.y-125),16,CORAL,true,true,2)
	for i in range(runner.members.size()-1,-1,-1):
		var member=runner.members[i]
		var kind=int(member.get("death_kind",member.kind)) if member.falling else (runner.perk_kind if runner.perk_left>0 else int(member.kind))
		var state=animation_state(member)
		var foot=Vector2(runner.member_x(i),member.y-int(i/8)*12)
		if state=="fly": foot.y+=sin(runner.elapsed*7+i)*3
		var height=112.0*(1+sin(member.arrival/.35*PI)*.10)
		var phase=(.62-float(member.attack_left))/.62 if state=="capture" else runner.world_px/84.0+i*.17
		if not member.falling:
			var shadow_size=clampf(1-(HordeRun.FLOOR-member.y)/420,.25,1)
			draw_set_transform(Vector2(foot.x,HordeRun.FLOOR+4),0,Vector2(23*shadow_size,4*shadow_size))
			draw_circle(Vector2.ZERO,1,Color(.02,.01,.05,.28*shadow_size))
			draw_set_transform(Vector2.ZERO)
			if runner.shields>0: draw_arc(foot-Vector2(0,56),62,0,TAU,32,Color(.5,.9,1,.4),3,true)
		var blink=Color(1,1,1,.45) if runner.hit_grace>0 and int(ui_time*14)%2==0 else Color.WHITE
		actor.paint(self,kind,foot,height,phase,state,runner.elapsed+i*.071,float(member.land_left),blink)
	for e in runner.entities:
		if not e.taken and e.kind in ["civilian","soldier"] and e.state=="capture": draw_civilian(e)
	effects.paint(self,art,actor)

func draw_run_hud() -> void:
	var positions=[28,215,380,545]
	var widths=[170,150,150,145]
	var labels=["DISTÂNCIA","HORDA","ALMAS","MOEDAS"]
	var values=[str(runner.distance())+" m",str(runner.active_count()),str(runner.souls),str(runner.coins)]
	for i in range(4):
		panel(Rect2(positions[i],24,widths[i],88),Color(.12,.07,.19,.93),Color("776077"),18)
		text(labels[i],Vector2(positions[i]+17,53),14,MINT,true)
		text(values[i],Vector2(positions[i]+17,94),28,GOLD if i in [2,3] else CREAM,true,false,2)
	if runner.perk_left>0 or runner.boost_left>0:
		panel(Rect2(707,24,370,88),Color(.20,.10,.29,.94),Color("be99df"),20)
		floating_item((0 if runner.perk_kind==3 else 11) if runner.perk_left>0 else 5,Vector2(742,68),46)
		text(("MOSCA MUTANTE" if runner.perk_kind==3 else "MASCARADOS") if runner.perk_left>0 else "FRENESI",Vector2(779,57),18,MINT,true)
		text(str(ceili(runner.perk_left if runner.perk_left>0 else runner.boost_left))+" segundos",Vector2(779,88),19,CREAM)
		var duration=(7.0 if runner.perk_kind==3 else 9.0)+int(data.levels.perk)*2 if runner.perk_left>0 else 5.0
		draw_rect(Rect2(779,99,266*(runner.perk_left if runner.perk_left>0 else runner.boost_left)/duration,4),MINT)
	button(Rect2(1160,28,83,73),"II","pause",Color("513565"),-2,27)
	text(MonsterCatalog.AREAS[runner.area()].name.to_upper()+"  •  TÚNEL "+str(runner.tunnel_number()),Vector2(32,148),16,MonsterCatalog.AREAS[runner.area()].color,true,false,2)
	var tunnel=runner.current_tunnel()
	if runner.inside_tunnel():
		text("TÚNEL "+str(tunnel.number)+"  •  À FRENTE: "+MonsterCatalog.AREAS[int(tunnel.to)].name.to_upper(),Vector2(640,196),21,GOLD,true,true,3)
	elif runner.recovery_left>0: text("REAGRUPE! MAIS CIVIS À FRENTE",Vector2(33,178),14,MINT,true,false,2)
	elif not tunnel.is_empty(): text("PRÓXIMO TÚNEL EM "+str(maxi(0,int((float(tunnel.entry)-runner.world_px)/30)))+" m",Vector2(33,178),14,CREAM,true,false,2)
	button(Rect2(1053,578,190,107),"MERGULHAR" if runner.perk_kind==3 and runner.perk_left>0 else "PULAR","jump",Color("8753aa"),-2,26)
	if runner.perk_kind==3 and runner.perk_left>0:
		text("SEGURE PARA DESCER • SOLTE PARA SUBIR",Vector2(687,671),15,MINT,true,true,2)
	elif runner.world_px<2200:
		panel(Rect2(375,635,587,53),Color(.12,.07,.19,.9),Color("736377"),20)
		text("CAPTURE CIVIS  •  TOQUE PARA PULAR",Vector2(668,669),18,CREAM,true,true)
	elif int(data.levels.jump)>=2: text("SALTO DUPLO LIBERADO",Vector2(683,675),16,MINT,true,true,2)

func draw_pause() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.04,.015,.08,.78))
	text("PAUSA",Vector2(73,103),48,GOLD,true,false,5)
	text("MISSÕES DA FUGA  •  CAPÍTULO "+str(int(data.mission_tier)+1),Vector2(77,145),20,MINT,true)
	var missions=MonsterCatalog.active_missions(int(data.mission_tier))
	for i in range(3):
		var mission=missions[i]
		var progress=int(data.mission_progress.get(mission.id,0))
		var done=mission.key in data.claimed
		panel(Rect2(73,181+i*138,744,122),Color(.18,.11,.26,.97),MINT if done else Color("79558b"),19,2)
		scenery.sprite(self,art.ritual[0],Vector2(126,235+i*138),52,Color.WHITE if done else Color(.75,.70,.84,1))
		text(mission.title,Vector2(178,219+i*138),22,GOLD,true,false,2)
		text("CONCLUÍDA" if done else str(maxi(0,int(mission.target)-progress))+" RESTANTES",Vector2(179,252+i*138),19,MINT if done else CREAM,true)
		progress_bar(Rect2(179,270+i*138,400,9),float(progress)/float(mission.target),MINT)
		text("+"+str(mission.ritual)+" RITUAL",Vector2(620,271+i*138),16,MINT,true)
	button(Rect2(864,187,343,83),"CONTINUAR","resume",Color("9370b6"),-2,28)
	button(Rect2(864,292,343,75),"RECOMEÇAR","retry",Color("6a7a81"),-2,24)
	button(Rect2(864,389,343,75),"MENU","home",Color("765269"),-2,27)
	button(Rect2(864,493,343,65),"SOM: ON" if data.audio else "SOM: OFF","audio",Color("53736e"),-2,22)
	text("As recompensas das missões vão ao ritual após encerrar a fuga.",Vector2(78,655),18,CREAM)
	text("NÍVEL "+str(data.player_level)+"  •  "+str(runner.souls)+" ALMAS NESTA PARTIDA",Vector2(78,688),16,MINT,true)

func draw_results() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(.035,.012,.07,.80))
	text("FIM DA HORDA",Vector2(70,100),46,GOLD,true,false,5)
	text("As almas coletadas continuam com você.",Vector2(74,138),21,MINT)
	panel(Rect2(67,166,760,414),Color(.18,.10,.25,.97),Color("b79ac0"),24,3)
	var animated=mini(runner.souls,int(result_time*16))
	var view=HordeProgress.board(int(run_report.get("old_level",data.player_level)),int(run_report.get("old_progress",data.level_souls)),animated)
	text("RESERVA DE ALMAS",Vector2(91,204),21,GOLD,true)
	text("NÍVEL "+str(view.level)+"  •  "+str(view.progress)+" / "+str(view.target),Vector2(650,206),20,MINT,true,true)
	draw_soul_grid(Rect2(93,230,700,258),int(view.progress),int(view.target))
	progress_bar(Rect2(95,506,702,13),float(view.progress)/float(view.target),MINT)
	var completed=animated>=runner.souls
	text("+"+str(runner.souls)+" ALMAS DESTA FUGA",Vector2(95,555),20,CREAM,true)
	if completed and int(run_report.get("levels",0))>0:
		text("+"+str(run_report.levels)+" NÍVEL!",Vector2(680,555),20,GOLD,true,true,2)
	panel(Rect2(852,166,359,414),Color(.18,.10,.25,.97),Color("b79ac0"),24,3)
	scenery.sprite(self,art.ritual[0],Vector2(898,215+sin(ui_time*3)*3),48)
	text(str(runner.souls)+" ALMAS",Vector2(938,230),29,GOLD,true,false,2)
	text("RECORDE: "+str(data.best_souls)+" ALMAS",Vector2(878,269),17,MINT,true)
	text(str(runner.distance())+" m",Vector2(878,321),35,CREAM,true,false,2)
	text("RECORDE: "+str(data.best)+" m",Vector2(878,352),17,MINT,true)
	text("+"+str(runner.coins)+" moedas  •  "+str(runner.cars)+" veículos",Vector2(878,393),17,CREAM)
	var points=0
	for item in data.ritual_pending: points+=int(item.points)
	text(str(points)+" PONTOS PARA O RITUAL",Vector2(878,432),17,MINT,true)
	if int(run_report.get("levels",0))>0 and completed:
		scenery.sprite(self,art.ritual[2],Vector2(917,504),78,Color.WHITE,sin(ui_time*8)*.05)
		text("BÔNUS DA SORTE",Vector2(969,481),16,GOLD,true)
		text("+"+str(run_report.coins)+" MOEDAS",Vector2(969,513),22,GOLD,true,false,2)
	else: wrapped("Encha a reserva para subir de nível e ganhar moedas da sorte!",Vector2(880,484),304,18,CREAM,3)
	text("CARTEIRA: "+str(data.wallet)+" MOEDAS",Vector2(92,613),19,GOLD,true)
	button(Rect2(67,640,228,62),"MENU","home",Color("5d426f"),-2,23)
	button(Rect2(318,640,285,62),"MELHORIAS","shop",Color("845eaa"),-2,23)
	button(Rect2(625,640,286,62),"DE NOVO","play",Color("c78a4b"),-2,25)
	text("NÍVEL DO JOGADOR "+str(data.player_level),Vector2(942,680),18,MINT,true)
	effects.paint(self,art,actor)

func validate_save(value) -> Dictionary:
	if not value is Dictionary or int(value.get("version",0)) not in [1,2,3,4]: return MonsterCatalog.defaults()
	var result=MonsterCatalog.defaults()
	result.wallet=clampi(int(value.get("wallet",120)),0,9999999)
	result.best=clampi(int(value.get("best",0)),0,9999999)
	result.runs=maxi(0,int(value.get("runs",0)))
	result.audio=bool(value.get("audio",true))
	result.player_level=clampi(int(value.get("player_level",1)),1,500)
	result.level_souls=clampi(int(value.get("level_souls",0)),0,HordeProgress.level_target(int(result.player_level))-1)
	for key in ["total_souls","best_souls","active_souls"]: result[key]=clampi(int(value.get(key,0)),0,9999999)
	result.ritual_progress=clampi(int(value.get("ritual_progress",0)),0,99)
	result.ritual_ready=bool(value.get("ritual_ready",false))
	var pending=value.get("ritual_pending",[])
	var pending_keys={}
	if pending is Array:
		for item in pending.slice(0,300):
			if not item is Dictionary: continue
			var key=str(item.get("key",""))
			if key.is_empty() or key.length()>60 or pending_keys.has(key): continue
			pending_keys[key]=true
			result.ritual_pending.append({"key":key,"title":str(item.get("title","Missão")).left(120),"points":clampi(int(item.get("points",0)),1,40)})
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
		if parsed is Dictionary and int(parsed.get("version",0)) in [1,2,3,4]: return validate_save(parsed)
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

func preview_course(world: float=0,count: int=4,kind: int=0) -> void:
	data.levels.horde=0;data.skin=kind
	start_run();capture_freeze=true
	runner.entities.clear();runner.events.clear();runner.next_segment=99999
	runner.world_px=world;runner.speed=350;runner.rng.seed=4014
	while runner.active_count()<count: runner.add_member(runner.active_count()%2,false)
	runner.update_tunnels();runner.events.clear()
	scenery.update(.1,runner)

func preview_ticks(count: int,held: bool=false) -> void:
	for i in range(count):
		runner.advance(1.0/60,held);consume_run_events();update_run_visuals(1.0/60)
		check_challenges();ui_time+=1.0/60
	toast_left=0;flash=0;shake=0

func preview_collect_souls(count: int) -> void:
	for i in range(count):
		var person=runner.add_entity("civilian",HordeRun.ANCHOR,HordeRun.FLOOR,i%3)
		person.vx=0;person.pose="run";person.group=999
		preview_ticks(45)
	for i in range(40): runner.add_entity("coin",HordeRun.ANCHOR,HordeRun.FLOOR-48)
	preview_ticks(2)

func capture_preview() -> void:
	capture_freeze=true
	await get_tree().create_timer(.4).timeout
	var path=OS.get_environment("HORDE_CAPTURE_PATH")
	if path.is_empty(): path="user://NoiteDaHorda-menu.png"
	var base=path.get_basename().trim_suffix("-menu")
	await capture_frame(base+"-menu.png")
	perform_action("shop");await capture_frame(base+"-shop.png")
	perform_action("monsters");await capture_frame(base+"-monsters.png")
	perform_action("worlds");await capture_frame(base+"-worlds.png")
	preview_course(1100,4)
	for i in range(3): runner.add_entity("civilian",620+i*110,HordeRun.FLOOR,i)
	runner.add_entity("bomb",970);runner.add_entity("air_bomb",1140,HordeRun.FLOOR-190)
	for i in range(6):runner.add_entity("coin",540+i*76,HordeRun.FLOOR-155)
	runner.jump();preview_ticks(11,true)
	await capture_frame(base+"-run.png")
	perform_action("pause");await capture_frame(base+"-pause.png");perform_action("resume")
	for kind in range(4):
		preview_course(0,1,kind)
		var npc=runner.add_entity("civilian",HordeRun.ANCHOR+7,HordeRun.FLOOR,kind%3);npc.vx=0;npc.pose="run"
		preview_ticks(14)
		await capture_frame(base+"-capture-"+["zombie","skeleton","masked","fly"][kind]+".png")
	preview_course(2000,4)
	var car=runner.add_entity("car",HordeRun.ANCHOR+float(MonsterCatalog.VEHICLES.car.width)*.5+12)
	while car.contacts.size()<2 and not car.taken:preview_ticks(1)
	await capture_frame(base+"-vehicle-count.png")
	preview_ticks(45)
	await capture_frame(base+"-passengers.png")
	preview_course(1100,4)
	runner.grant_perk(3);preview_ticks(65)
	runner.add_entity("gap",520,HordeRun.FLOOR,0,310);runner.add_entity("bomb",950)
	await capture_frame(base+"-perk.png")
	preview_course(17850,8);await capture_frame(base+"-tunnel-entry.png")
	preview_course(19050,8);await capture_frame(base+"-tunnel.png")
	preview_course(19920,8);await capture_frame(base+"-tunnel-exit.png")
	preview_course(22300,8)
	runner.add_entity("bus",970);runner.add_entity("bomb",600)
	runner.add_entity("soldier",760);runner.add_entity("helicopter",770,HordeRun.FLOOR-280)
	runner.add_entity("air_bomb",1130,HordeRun.FLOOR-180)
	scenery.crash_age=1.45
	await capture_frame(base+"-city.png")
	preview_course(22000,12);runner.route.assign([0,1,2,3]);runner.completed_tunnels=2;runner.entered_tunnels=2
	scenery.update(.1,runner);runner.add_entity("tank",710);runner.add_entity("truck",1100)
	await capture_frame(base+"-industrial.png")
	preview_course(22000,16);runner.route.assign([0,1,2,3]);runner.completed_tunnels=3;runner.entered_tunnels=3
	scenery.update(.1,runner);runner.add_entity("plane",895);runner.add_entity("moto",470)
	await capture_frame(base+"-airport.png")
	# Real physics/capture events feed the result board, mission ritual and pit death.
	data=MonsterCatalog.defaults();data.ritual_progress=70
	preview_course(22300,4);preview_collect_souls(24)
	runner.entities.clear();runner.add_entity("gap",HordeRun.ANCHOR-290,HordeRun.FLOOR,0,850)
	preview_ticks(90);end_delay=-1;change_screen("results")
	for i in range(135):update_rewards(1.0/60);ui_time+=1.0/60
	await capture_frame(base+"-gameover.png")
	perform_action("home")
	for i in range(108):update_rewards(1.0/60);ui_time+=1.0/60
	await capture_frame(base+"-ritual.png")
	perform_action("credits");await capture_frame(base+"-credits.png")
	print("HORDE_CAPTURE_OK: 22 real game screens including individual capture, occupied vehicles, traversable tunnel, pause, souls and ritual")
	get_tree().quit()

func animation_state(member: Dictionary) -> String:
	if member.falling: return "fall"
	if member.attack_left>0: return "capture"
	if member.push_left>0 and member.y>=HordeRun.FLOOR-12: return "push"
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
		text("RITUAL: +"+str(item.ritual)+" PONTOS",Vector2(x+181,521),18,GOLD,true,true)
	button(Rect2(68,632,240,66),"VOLTAR","back",Color("513c67"),-2,23)
	text("Complete missões, encerre a fuga e alimente o ritual no menu.",Vector2(350,671),20,MINT)

func motion_preview() -> void:
	capture_freeze=true
	await get_tree().create_timer(.3).timeout
	var folder=OS.get_environment("HORDE_MOTION_PATH")
	if folder.is_empty():folder="user://motion"
	DirAccess.make_dir_recursive_absolute(folder)
	var first_frame=maxi(0,int(OS.get_environment("HORDE_MOTION_START")))
	data=MonsterCatalog.defaults();data.ritual_progress=70
	preview_course(2000,4)
	for i in range(3):runner.add_entity("civilian",460+i*80,HordeRun.FLOOR,i)
	runner.add_entity("car",800)
	for frame in range(720):
		ui_time=float(frame)/30.0
		if frame==80:
			runner.entities.clear();runner.world_px=17800;runner.speed=400
			while runner.active_count()<8:runner.add_member(runner.active_count()%2,false)
		if frame==310:
			runner.entities.clear();runner.world_px=22300;runner.update_tunnels()
			while runner.active_count()<16:runner.add_member(runner.active_count()%2,false)
			runner.add_entity("plane",890);runner.add_entity("civilian",440,HordeRun.FLOOR,2)
		if frame==418:
			runner.entities.clear();runner.grant_perk(3)
			runner.add_entity("gap",470,HordeRun.FLOOR,0,280)
			runner.add_entity("helicopter",970,HordeRun.FLOOR-280)
			runner.add_entity("bomb",1160);runner.add_entity("air_bomb",1300,HordeRun.FLOOR-175)
		if frame==490:
			# New prepared course: actual captures, actual souls, then fatal pit.
			data=MonsterCatalog.defaults();data.ritual_progress=70
			preview_course(22300,4);preview_collect_souls(24)
			runner.entities.clear();runner.add_entity("gap",HordeRun.ANCHOR+10,HordeRun.FLOOR,0,850)
		if frame==650:perform_action("home")
		var held=frame>=450 and frame<478
		if screen=="run":
			runner.advance(1.0/60,held);runner.advance(1.0/60,held)
			consume_run_events();check_challenges();update_run_visuals(1.0/30)
			if end_delay>=0:
				end_delay-=1.0/30
				if end_delay<0:change_screen("results")
		elif screen in ["results","home"]:update_rewards(1.0/30)
		toast_left=maxf(0,toast_left-1.0/30)
		flash=maxf(0,flash-1.0/30*1.7);shake=maxf(0,shake-1.0/30*20)
		if frame>=first_frame:await capture_frame(folder+"/frame-%04d.png"%frame)
	print("HORDE_MOTION_OK: 720 real rendered frames; prepared courses and simulated touch; individual captures, contact flips, tunnel traversal, flight, pit game over, soul board and ritual")
	get_tree().quit()

func draw_vehicle(entity: Dictionary) -> void:
	var spec=MonsterCatalog.VEHICLES[entity.kind]
	var height=float(spec.height);var width=float(spec.width)
	var angle=float(entity.tilt)+sin(ui_time*3+entity.bob)*.006
	var point=Vector2(entity.x,entity.y-height*.5-sin(angle)*height*.15)
	draw_set_transform(point,angle,Vector2(-1 if spec.reverse else 1,1))
	draw_texture_rect(art.vehicle(entity.kind),Rect2(-width*.5,-height*.5,width,height),false)
	draw_set_transform(Vector2.ZERO)
	for i in range(spec.windows.size()):
		var offset=Vector2(spec.windows[i].x*width,spec.windows[i].y*height)
		var npc=int(entity.passengers[i%entity.passengers.size()]) if not entity.passengers.is_empty() else 0
		actor.passenger(self,int(MonsterCatalog.CIVILIANS[npc].rig),point+offset.rotated(angle),float(spec.get("passenger_height",40)),ui_time+i*.3,angle)
	if entity.kind=="plane":
		for x in [-width*.14,width*.22]:
			var start=point+Vector2(x,-10-sin(ui_time*60)*height*.11).rotated(angle)
			var end=point+Vector2(x,-10+sin(ui_time*60)*height*.11).rotated(angle)
			draw_line(start,end,Color(.9,.94,1,.72),3,true)
	var count=entity.contacts.size()
	var color=MINT if count>=int(spec.need) else (GOLD if count>0 else CORAL)
	var label=str(count)+" / "+str(spec.need) if count>0 else "VIRAR: "+str(spec.need)
	panel(Rect2(entity.x-70,entity.y-height-51,140,37),Color(.13,.08,.19,.96),color,12,2,false)
	text(label,Vector2(entity.x,entity.y-height-25),19,color,true,true,1)
	if count>0: progress_bar(Rect2(entity.x-63,entity.y-height-10,126,6),float(count)/float(spec.need),color)

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

func progress_bar(rect: Rect2,value: float,color: Color) -> void:
	panel(rect,Color("21152f"),Color("463154"),int(rect.size.y*.5),1,false)
	if value>0: panel(Rect2(rect.position,Vector2(maxf(5,rect.size.x*clampf(value,0,1)),rect.size.y)),color,color.lightened(.12),int(rect.size.y*.5),0,false)

func draw_fuse(point: Vector2,time: float) -> void:
	draw_circle(point-Vector2(0,11),26,Color(1,.5,.13,.10+.025*sin(time*12)))
	var texture=art.vfx[posmod(int(time*11),3)]
	var size=texture.get_size()*(26.0/texture.get_height())
	draw_texture_rect(texture,Rect2(point-Vector2(size.x*.5,size.y),size),false)
	for i in range(3):
		var age=fposmod(time*1.7+i*.33,1)
		draw_circle(point+Vector2(sin(time*7+i)*11*age,-age*33),1.7*(1-age),Color(1,.81,.30,.8*(1-age)))

func draw_civilian(entity: Dictionary) -> void:
	var spec=MonsterCatalog.CIVILIANS[clampi(int(entity.variant),0,2)]
	var rig=5 if entity.kind=="soldier" else int(spec.rig)
	var state="panic_run" if entity.pose=="panic" else "run"
	var height=float(spec.height)
	var foot=Vector2(entity.x,entity.y)
	var tint=Color.WHITE
	if entity.state=="capture":
		var progress=1-float(entity.capture_left)/.62
		state="panic";foot.x-=progress*16;foot.y-=sin(progress*PI)*12
		height*=1-maxf(0,progress-.60)*1.5;tint.a=1-maxf(0,progress-.72)*2.5
		if progress>.35:
			var texture=art.vfx[3+mini(2,int(progress*3))]
			var size=texture.get_size()*(80.0/texture.get_height())
			draw_texture_rect(texture,Rect2(foot-Vector2(size.x*.5,73),size),false,Color(1,1,1,progress*.8))
	elif entity.pose=="hop" and entity.y<HordeRun.FLOOR-10: state="rise"
	actor.paint(self,rig,foot,height,entity.age*3.1+entity.bob,state,ui_time,0,tint,entity.vx<0)
	if entity.state=="normal" and entity.x>HordeRun.ANCHOR+100: text("ALMA",Vector2(entity.x,entity.y-height-19),13,MINT,true,true,2)

func begin_ritual() -> void:
	if not data.ritual_ready: return
	ritual_view=HordeProgress.ritual(data,reward_rng);ritual_time=0;ritual_particle_tick=0;ritual_reward_played=false
	save_game()
	if int(ritual_view.points)>0:
		effects.clear();sound.play("ritual_fill",-13)

func update_rewards(dt: float) -> void:
	effects.update(dt,0)
	if screen=="home":
		ritual_time+=dt;ritual_particle_tick+=dt
		if not ritual_view.is_empty() and ritual_time<2.6 and int(ritual_view.points)>0 and ritual_particle_tick>.10:
			ritual_particle_tick=0
			effects.soul(Vector2(370+sin(ritual_time*8)*170,560),Vector2(174,409),.85)
		if not ritual_view.is_empty() and ritual_time>1.75 and int(ritual_view.bonuses)>0 and not ritual_reward_played:
			ritual_reward_played=true;sound.play("level_up",-13);effects.spark(Vector2(173,409),GOLD,30)
	else:
		result_time+=dt
		var animated=mini(runner.souls,int(result_time*16))
		var view=HordeProgress.board(int(run_report.get("old_level",data.player_level)),int(run_report.get("old_progress",data.level_souls)),animated)
		if int(view.level)>result_level:
			result_level=int(view.level);sound.play("level_up",-12);effects.spark(Vector2(420,300),MINT,32)

func draw_ritual_panel() -> void:
	panel(Rect2(78,349,650,146),Color(.12,.07,.20,.96),Color("8da690"),22,2)
	scenery.sprite(self,art.ritual[1],Vector2(173,431),114,Color.WHITE,sin(ui_time*2)*.014)
	for i in range(3):
		var angle=ui_time*1.6+i*TAU/3
		scenery.sprite(self,art.ritual[0],Vector2(173+cos(angle)*43,390+sin(angle)*16),23,Color(1,1,1,.8))
	text("RITUAL DA MADRUGADA",Vector2(272,385),20,MINT,true)
	var amount=float(data.ritual_progress)
	if not ritual_view.is_empty() and ritual_time<2.5:
		var value=float(ritual_view.old_progress)+float(ritual_view.points)*clampf(ritual_time/2.1,0,1)
		amount=fposmod(value,100)
	progress_bar(Rect2(272,410,427,15),amount/100,MINT)
	text(str(int(amount))+" / 100",Vector2(272,451),18,CREAM,true)
	if not ritual_view.is_empty() and int(ritual_view.coins)>0 and ritual_time>1.7:
		text("BÔNUS: +"+str(ritual_view.coins)+" MOEDAS",Vector2(416,451),18,GOLD,true,false,2)
	else: text("Complete missões para ganhar um bônus!",Vector2(272,478),16,CREAM)

func draw_soul_grid(rect: Rect2,progress: int,target: int) -> void:
	var cells=mini(120,target)
	var cols=5 if cells<=25 else (6 if cells<=42 else (10 if cells<=60 else 12))
	var rows=ceili(float(cells)/cols)
	var cell=Vector2((rect.size.x-(cols-1)*6)/cols,(rect.size.y-(rows-1)*6)/rows)
	var filled=float(progress)/maxi(1,target)*cells
	for i in range(cells):
		var point=rect.position+Vector2(i%cols,int(i/cols))*(cell+Vector2(6,6))
		var active=float(i)<filled
		panel(Rect2(point,cell),Color("31444c") if active else Color("251a32"),Color("7ac5b3") if active else Color("4b355e"),8,1,false)
		var centre=point+cell*.5+Vector2(0,sin(ui_time*3+i)*(.8 if active else 0))
		var size=minf(cell.y*.76,cell.x*.73)
		scenery.sprite(self,art.ritual[0],centre,size,Color.WHITE if active else Color(.17,.13,.24,.8))

func draw_credits() -> void:
	text("CRÉDITOS E FONTES",Vector2(69,107),42,GOLD,true,false,5)
	panel(Rect2(69,158,1142,452),Color(.16,.10,.23,.96),Color("785682"),24,2)
	var lines=["Arte e animações: Noite da Horda. Imagens geradas com o gerador integrado; animações criadas no motor.","Músicas, efeitos de almas e ritual: composições originais do projeto.","Ki Ki Ki Ma Ma Ma: alexander / Orange Free Sounds — CC BY 4.0. Conversão e normalização do volume.","Fonte do sussurro: orangefreesounds.com/ki-ki-ki-ma-ma-ma/  •  Licença: creativecommons.org/licenses/by/4.0/", "Zumbis, ossos, grito e respiração: artisticdude, congusbongus/blukotek, pauliuw e qubodup — CC0, OpenGameArt.","Fontes: Bungee (SIL OFL) e DejaVu Sans. Motor Godot — MIT.","Fontes, licenças e prompts completos: repositório PS4-Career-Diagnostic, pasta monster-game/ASSETS.md."]
	for i in range(lines.size()): wrapped(lines[i],Vector2(94,197+i*57),1092,18,CREAM,2)
	button(Rect2(69,641,240,61),"VOLTAR","back",Color("513c67"),-2,23)
