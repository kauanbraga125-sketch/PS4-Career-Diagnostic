class_name HordeViews
extends RefCounted

var selected=0
var jar=HordeSoulJar.new()

func heading(g,title: String,subtitle: String="") -> void:
	g.home_menu.label(g,title,Vector2(68,96),43,g.GOLD,false,900,true,4)
	if not subtitle.is_empty():g.home_menu.label(g,subtitle,Vector2(70,135),20,g.MINT,false,1040)

func card(g,rect: Rect2,active: bool=false) -> void:
	g.home_menu.slab(g,rect,Color("30213f"),g.MINT if active else Color("806583"),14,5)
	# Chipped corners and inner bevel are shared across all menu panels.
	g.paint_target.draw_line(rect.position+Vector2(9,22),rect.position+Vector2(20,32),Color("513456"),2,true)
	g.paint_target.draw_line(rect.end-Vector2(26,8),rect.end-Vector2(17,20),Color("513456"),2,true)

func mission_icon(g,mission: Dictionary,point: Vector2,height: float) -> void:
	if mission.stat=="cars":g.scenery.sprite(g,g.art.vehicle("car"),point,height*.75)
	elif mission.stat in ["clean_jumps","jumps","distance"]:g.item_sprite(4,point,height)
	elif mission.stat in ["bonuses","flights"]:g.item_sprite(0,point,height)
	elif mission.stat in ["souls","recruits"]:g.animated_soul(point,height,g.ui_time)
	else:g.item_sprite(1,point,height)

func missions(g) -> void:
	heading(g,"MISSÕES DA MADRUGADA","CAPÍTULO "+str(int(g.data.mission_tier)+1)+"  •  COMPLETE O TRIO")
	g.currency()
	var missions=MonsterCatalog.active_missions(int(g.data.mission_tier))
	for i in range(3):
		var m=missions[i];var x=68+i*393;var progress=int(g.data.mission_progress.get(m.id,0));var done=m.key in g.data.claimed
		card(g,Rect2(x,190,362,406),done)
		mission_icon(g,m,Vector2(x+181,274+sin(g.ui_time*2+i)*3),86)
		if done:
			g.draw_circle(Vector2(x+309,222),18,g.MINT)
			g.home_menu.label(g,"✓",Vector2(x+309,230),24,Color("20352f"))
		g.home_menu.label(g,m.title,Vector2(x+181,367),25,g.GOLD,true,324)
		g.home_menu.label(g,"CONCLUÍDA" if done else str(progress)+" / "+str(m.target),Vector2(x+181,416),28,g.MINT if done else g.CREAM)
		g.progress_bar(Rect2(x+32,444,298,15),float(progress)/float(m.target),g.MINT if done else g.GOLD)
		g.panel(Rect2(x+40,495,282,65),Color("21182f"),Color("655272"),13,1,false)
		g.animated_soul(Vector2(x+75,527),37,g.ui_time+i)
		g.home_menu.label(g,"+"+str(m.ritual)+" PARA O RITUAL",Vector2(x+204,536),20,g.MINT,true,218)
	g.button(Rect2(68,640,244,56),"VOLTAR","back",Color("513c67"),-2,23)

func pause(g) -> void:
	g.draw_rect(g.full_rect(),Color(.025,.012,.055,.82))
	heading(g,"PAUSA","MISSÕES DA FUGA  •  CAPÍTULO "+str(int(g.data.mission_tier)+1))
	g.home_menu.label(g,"NÍVEL "+str(g.data.player_level)+"  •  "+str(g.runner.souls)+" ALMAS",Vector2(1035,104),20,g.MINT,true,340)
	var missions=MonsterCatalog.active_missions(int(g.data.mission_tier))
	for i in range(3):
		var m=missions[i];var y=183+i*139;var progress=int(g.data.mission_progress.get(m.id,0));var done=m.key in g.data.claimed
		card(g,Rect2(68,y,746,123),done)
		mission_icon(g,m,Vector2(125,y+57+sin(g.ui_time*2+i)*2),63)
		g.home_menu.label(g,m.title,Vector2(181,y+35),24,g.GOLD,false,474)
		g.home_menu.label(g,"CONCLUÍDA" if done else "FALTA "+str(maxi(0,int(m.target)-progress)),Vector2(183,y+65),19,g.MINT if done else g.GOLD,false,360)
		g.progress_bar(Rect2(182,y+86,381,12),float(progress)/float(m.target),g.MINT if done else g.GOLD)
		g.animated_soul(Vector2(627,y+70),40,g.ui_time+i)
		g.home_menu.label(g,"+"+str(m.ritual),Vector2(707,y+75),25,g.MINT,true,105)
		g.home_menu.label(g,"RITUAL",Vector2(707,y+100),15,g.MINT,true)
	g.button(Rect2(855,185,356,90),"▶  CONTINUAR","resume",Color("c58a35"),-2,30)
	g.button(Rect2(855,298,356,78),"RECOMEÇAR","retry",Color("58416d"),-2,25)
	g.button(Rect2(855,401,356,78),"MENU","home",Color("58416d"),-2,25)
	g.button(Rect2(855,509,356,66),"CONFIGURAÇÕES","settings",Color("58416d"),-2,23)

func results(g) -> void:
	g.draw_rect(g.full_rect(),Color(.025,.012,.055,.84))
	heading(g,"FIM DA HORDA","A horda caiu. As almas permanecem.")
	g.currency()
	card(g,Rect2(68,175,526,431))
	g.home_menu.label(g,"RESERVA DE ALMAS",Vector2(331,210),22,g.GOLD)
	var animated=g.animated_result_souls()
	var view=HordeProgress.board(int(g.run_report.get("old_level",g.data.player_level)),int(g.run_report.get("old_progress",g.data.level_souls)),animated)
	var fill=float(view.progress)/float(view.target)
	# Hold a full sprite briefly on the exact level boundary, before showing carry-over.
	if g.result_full_flash>0:fill=1.0
	jar.paint(g,Rect2(211,221,240,300),fill,g.ui_time)
	for i in range(mini(5,maxi(1,int(fill*7))) if fill>0 else 0):
		var y=lerpf(456,343,float(i+1)/6.0)+sin(g.ui_time*2+i)*6
		g.animated_soul(Vector2(319+sin(i*2.3+g.ui_time*.4)*47,y),29,g.ui_time+i)
	g.home_menu.label(g,"+"+str(animated)+" ALMAS DESTA FUGA",Vector2(331,536),23,g.GOLD,true,470)
	g.home_menu.label(g,"NÍVEL "+str(view.level),Vector2(91,570),20,g.CREAM,false)
	g.home_menu.label(g,str(view.progress)+" / "+str(view.target),Vector2(562,570),20,g.MINT,true)
	g.progress_bar(Rect2(91,583,480,10),fill,g.MINT)
	var stats=[{"label":"ALMAS","value":str(g.runner.souls),"note":"RECORDE: "+str(g.data.best_souls),"icon":0},
		{"label":"DISTÂNCIA","value":str(g.runner.distance())+" m","note":"RECORDE: "+str(g.data.best)+" m","icon":-1},
		{"label":"MOEDAS","value":"+"+str(g.runner.coins),"note":"GANHAS NESTA FUGA","icon":1},
		{"label":"VEÍCULOS VIRADOS","value":str(g.runner.cars),"note":"A HORDA DEIXOU SUA MARCA","icon":7}]
	for i in range(4):
		var rect=Rect2(620+(i%2)*302,175+(i/2)*166,288,153)
		card(g,rect)
		g.home_menu.label(g,stats[i].label,rect.position+Vector2(20,31),18,g.MINT,false,248)
		g.home_menu.label(g,stats[i].value,rect.position+Vector2(23,88),39,g.GOLD,false,204)
		g.home_menu.label(g,stats[i].note,rect.position+Vector2(20,124),14,g.CREAM,false,252)
		if stats[i].icon==0:g.animated_soul(rect.position+Vector2(239,73),48,g.ui_time)
		elif stats[i].icon>=0:g.item_sprite(stats[i].icon,rect.position+Vector2(239,73),44)
	var points=0
	for item in g.data.ritual_pending:points+=int(item.points)
	card(g,Rect2(620,513,590,93))
	g.animated_soul(Vector2(660,557),47,g.ui_time)
	g.home_menu.label(g,"+"+str(points)+" PONTOS PARA O RITUAL",Vector2(706,552),22,g.MINT,false,470)
	if animated>=g.runner.souls and int(g.run_report.get("levels",0))>0:g.home_menu.label(g,"+"+str(g.run_report.coins)+" MOEDAS DA SORTE",Vector2(706,583),19,g.GOLD,false,470)
	else:g.home_menu.label(g,"Cada alma alimenta a próxima ascensão.",Vector2(706,583),17,g.CREAM,false,470)
	g.button(Rect2(68,639,248,59),"MENU","home",Color("58416d"),-2,24)
	g.button(Rect2(337,639,344,59),"MELHORIAS","shop",Color("715090"),-2,24)
	g.button(Rect2(705,632,505,66),"▶  DE NOVO","play",Color("c58a35"),-2,29)

func collection(g) -> void:
	heading(g,"COLEÇÃO DA HORDA",str(g.data.owned.size())+" / 2 MONSTROS DESBLOQUEADOS")
	for i in range(2):
		var rect=Rect2(68,198+i*174,238,157);var owned=i in g.data.owned
		card(g,rect,selected==i)
		g.scenery.sprite(g,g.art.rigs[i][0],rect.position+Vector2(62,71),78,Color.WHITE if owned else Color(.23,.20,.28,1))
		g.home_menu.label(g,MonsterCatalog.MONSTERS[i].name.to_upper(),rect.position+Vector2(118,69),20,g.GOLD,false,110)
		g.home_menu.label(g,"LIBERADO" if owned else "BLOQUEADO",rect.position+Vector2(119,101),15,g.MINT if owned else g.CORAL,false,110)
		g.buttons.append({"rect":rect,"action":"collection_select_"+str(i)})
	var unlocked=selected in g.data.owned
	g.draw_set_transform(Vector2(566,573),0,Vector2(106,10));g.draw_circle(Vector2.ZERO,1,Color(.02,.01,.05,.45));g.draw_set_transform(Vector2.ZERO)
	g.actor.paint(g,selected,Vector2(566,566),319,g.ui_time*.55,"idle",g.ui_time,0,Color.WHITE if unlocked else Color(.3,.26,.35,1),false,1,false)
	g.home_menu.label(g,MonsterCatalog.MONSTERS[selected].name.to_upper(),Vector2(566,606),27,g.GOLD)
	g.home_menu.label(g,"PODERES TEMPORÁRIOS",Vector2(1020,196),22,g.GOLD)
	for i in range(2):
		var kind=3 if i==0 else 2;var rect=Rect2(849,220+i*177,361,153);var owned=kind in g.data.power_owned
		card(g,rect,owned)
		g.scenery.sprite(g,g.art.power(kind,g.ui_time),rect.position+Vector2(69,75+sin(g.ui_time*2+i)*4),95)
		g.home_menu.label(g,"SUPER FLY" if kind==3 else "MASCARADO",rect.position+Vector2(137,52),24,g.GOLD,false,205)
		g.home_menu.label(g,"TEMPORÁRIO",rect.position+Vector2(139,83),17,g.MINT,false)
		g.home_menu.label(g,"LIBERADO" if owned else "NO MERCADO",rect.position+Vector2(139,118),17,g.CREAM,false)
	g.button(Rect2(68,641,238,57),"VOLTAR","back",Color("513c67"),-2,23)
	g.button(Rect2(849,641,361,57),"VER MONSTROS","market_monsters",Color("a97432"),-2,23)
