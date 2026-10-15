class_name HordeMarket
extends RefCounted

var category=0
var page=0
var scroll=0.0
var max_scroll=0.0
var selected=""
var expanded: Dictionary={}
const TITLES=["MELHORIAS","MONSTROS","PODERES","CENÁRIOS"]

func open(tab: int=0) -> void:
	category=clampi(tab,0,3);page=0;scroll=0;selected="";expanded.clear()

func update(dt: float) -> void:
	for key in expanded:expanded[key]=move_toward(float(expanded[key]),1.0 if key==selected else 0.0,dt*7)

func select(key: String) -> void:
	selected="" if selected==key else key
	if not expanded.has(key):expanded[key]=0.0

func items(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	match category:
		0:
			for i in range(3):
				var item=MonsterCatalog.UPGRADES[i]
				var level=int(data.levels[item.id])
				result.append({"key":"upgrade"+str(i),"name":item.name,"description":item.description,"level":"NÍVEL "+str(level)+" / "+str(item.max),"price":MonsterCatalog.upgrade_cost(item,level),"full":level>=int(item.max),"action":"buy_"+str(i),"illustration":"upgrade","index":i,"kind":0})
		1:
			for i in range(2):
				var item=MonsterCatalog.MONSTERS[i]
				result.append({"key":"monster"+str(i),"name":item.name.to_upper(),"description":"Seu primeiro monstro. Capture civis para aumentar a horda." if i==0 else "Após a compra, cada civil capturado tem 30% de chance de virar esqueleto.","level":"MONSTRO DA COLEÇÃO","price":MonsterCatalog.SKIN_PRICES[i],"full":i in data.owned,"action":"skin_"+str(i),"illustration":"monster","index":i,"kind":i})
		2:
			for item in MonsterCatalog.POWERS:
				result.append({"key":"power"+str(item.kind),"name":item.name,"description":item.description+" Aparece na pista como transformação temporária.","level":"PODER TEMPORÁRIO","price":item.price,"full":item.kind in data.power_owned,"action":"power_buy_"+str(item.kind),"illustration":"power","index":item.kind,"kind":item.kind})
			for i in range(MonsterCatalog.POWER_UPGRADES.size()):
				var item=MonsterCatalog.POWER_UPGRADES[i]
				var level=int(data.power_levels[item.id])
				result.append({"key":"powerupgrade"+str(i),"name":item.name,"description":item.description,"level":("SUPER FLY" if item.kind==3 else "MASCARADO")+"  •  NÍVEL "+str(level)+" / "+str(item.max),"price":MonsterCatalog.upgrade_cost(item,level),"full":level>=int(item.max),"locked":item.kind not in data.power_owned,"action":"power_upgrade_"+str(i),"illustration":"power_upgrade","index":i,"kind":item.kind})
		3:
			for i in range(4):
				var item=MonsterCatalog.AREAS[i]
				result.append({"key":"area"+str(i),"name":item.name.to_upper(),"description":item.description,"level":"REGIÃO DA FUGA","price":item.price,"full":i in data.areas,"action":"area_"+str(i),"illustration":"area","index":i,"kind":0})
	return result

func illustration(g,item: Dictionary,p: Vector2) -> void:
	match item.illustration:
		"monster":g.actor.paint(g.paint_target,item.kind,p+Vector2(0,37),75,g.ui_time*.7,"idle",g.ui_time,0,Color.WHITE,false,1,false)
		"power":g.scenery.sprite(g.paint_target,g.art.power(item.kind,g.ui_time),p,70,Color.WHITE,sin(g.ui_time*2)*.04)
		"area":g.paint_target.draw_texture_rect(g.art.world_thumbnails[item.index],Rect2(p-Vector2(46,40),Vector2(198,83)),false)
		"upgrade":
			if item.index==0:
				for i in range(2):g.scenery.sprite(g.paint_target,g.art.rigs[0][0],p+Vector2(i*22-10,i*5),45)
			else:g.floating_item(MonsterCatalog.UPGRADES[item.index].icon,p,58)
		"power_upgrade":
			g.scenery.sprite(g.paint_target,g.art.rigs[item.kind][0],p-Vector2(11,3),52)
			var icon=[4,4,7,2,0,9][item.index]
			g.floating_item(icon,p+Vector2(19,20),34)

func scroll_by(delta: float) -> void:
	scroll=clampf(scroll+delta,0,max_scroll)

func paint(g) -> void:
	g.views.heading(g,"MERCADO",["Prepare a horda para ir mais longe.","Novos monstros para a sua coleção.","Transformações e suas melhorias.","Novas regiões entram na próxima corrida."][category])
	g.currency()
	for i in range(4):
		var rect=Rect2(68,184+i*91,244,75)
		g.home_menu.slab(g,rect,Color("58456c") if category==i else Color("2d203f"),g.GOLD if category==i else Color("725568"),12,4)
		g.home_menu.label(g,TITLES[i],rect.get_center()+Vector2(0,9),24,g.GOLD if category==i else g.CREAM,true,224)
		g.buttons.append({"rect":rect,"action":"market_tab_"+str(i)})

	if max_scroll>0:
		g.panel(Rect2(1207,184,7,424),Color("241a31"),Color("584466"),3,0,false)
		var thumb=maxf(44,424*424/(max_scroll+424))
		g.panel(Rect2(1207,184+(424-thumb)*scroll/max_scroll,7,thumb),g.MINT,g.MINT,3,0,false)
		g.home_menu.label(g,"↕  ARRASTE PARA VER MAIS",Vector2(766,641),16,g.MINT,true,690)
	g.button(Rect2(68,641,244,55),"VOLTAR","back",Color("513c67"),-2,22)

func paint_rows(g) -> void:
	var entries=items(g.data);var content_height=0.0
	for item in entries:content_height+=117+76*float(expanded.get(item.key,0))
	max_scroll=maxf(0,content_height-424);scroll=clampf(scroll,0,max_scroll)
	var y=184.0-scroll
	for item in entries:
		var mix=float(expanded.get(item.key,0));var height=103+76*mix
		var rect=Rect2(339,y,853,height);y+=height+14
		# Rows stay inside the content window, so header, categories and back never move.
		if rect.end.y<179 or rect.position.y>614:continue
		var active=selected==item.key
		g.views.card(g,rect,active)
		g.buttons.append({"rect":rect.intersection(Rect2(339,179,853,435)),"action":"market_select_"+str(item.key)})
		g.panel(Rect2(rect.position+Vector2(10,10),Vector2(95,83)),Color("1f192e"),Color("5c5966"),12,1,false)
		illustration(g,item,rect.position+Vector2(57,52))
		var text_x=229 if item.illustration=="area" else 123
		g.home_menu.label(g,item.name,rect.position+Vector2(text_x,36),25,g.GOLD,false,385 if text_x==229 else 494)
		g.home_menu.label(g,item.level,rect.position+Vector2(text_x+1,69),17,g.MINT,false,385 if text_x==229 else 494)
		var full=bool(item.full)
		var price=("NO MÁXIMO" if item.illustration in ["upgrade","power_upgrade"] else "LIBERADO") if full else str(item.price)+" MOEDAS"
		g.home_menu.label(g,price,rect.position+Vector2(634,37),18,g.MINT if full else g.GOLD,false,199)
		if mix>.80:
			g.wrapped(item.description,rect.position+Vector2(123,109),472,16,g.CREAM,2)
			var label="LIBERADO" if full else ("BLOQUEADO" if item.get("locked",false) else "COMPRAR")
			if full or item.get("locked",false):g.home_menu.label(g,label,rect.end-Vector2(109,30),17,g.MINT,true,178)
			else:g.button(Rect2(rect.end-Vector2(205,61),Vector2(185,43)),label,item.action,Color("a97432"),-2,22)
		else:g.home_menu.label(g,"DETALHES",rect.position+Vector2(635,73),16,Color("bca8c3"),false,192)
