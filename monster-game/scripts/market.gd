class_name HordeMarket
extends RefCounted

const TITLES = ["MELHORIAS", "MONSTROS", "PODERES", "CENÁRIOS"]
const SHEET = preload("res://assets/art/market-art-v82.png")
var category = 0
var page = 0
var scroll = 0.0
var max_scroll = 0.0
var selected = ""
var expanded: Dictionary = {}
var sprites: Dictionary = {}

func _init() -> void:
    var regions = {"logo":Rect2(8,82,1520,490),"shoe":Rect2(0,620,384,350),"magnet":Rect2(390,606,378,364),"potion":Rect2(768,598,384,378),"church":Rect2(1152,590,384,390)}
    for key in regions:
        var texture = AtlasTexture.new()
        texture.atlas = SHEET
        texture.region = regions[key]
        texture.filter_clip = true
        sprites[key] = texture

func open(tab: int = 0) -> void:
    category = clampi(tab,0,3)
    page = 0
    scroll = 0
    max_scroll = 0
    selected = ""
    expanded.clear()

func update(_dt: float) -> void:
    pass

func select(key: String) -> void:
    selected = key

func layout(view: Rect2) -> Dictionary:
    var margin = maxf(32,view.size.x*.055)
    var left = view.position.x+margin
    var right = view.end.x-margin
    var sidebar_width = clampf(view.size.x*.18,214,320)
    var top = view.position.y+190
    var grid = Rect2(left+sidebar_width+20,top,right-left-sidebar_width-20,view.size.y-238)
    var gap = 14.0
    var card_size = Vector2((grid.size.x-gap)*.5,(grid.size.y-gap)*.5)
    var title_width = minf(view.size.x*.30,450)
    var title = Rect2(left-12,view.position.y+10,title_width,title_width*490/1520)
    var tabs: Array[Rect2] = []
    for i in range(4):
        tabs.append(Rect2(left,top+i*96,sidebar_width,84))
    return {"view":view,"title":title,"tabs":tabs,"grid":grid,"card_size":card_size,"gap":gap,
        "wallet":Rect2(right-218,view.position.y+28,218,72),
        "back":Rect2(left,grid.end.y-70,sidebar_width,70)}

func items(data: Dictionary) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    match category:
        0:
            for i in range(MonsterCatalog.UPGRADES.size()):
                var item = MonsterCatalog.UPGRADES[i]
                var level = int(data.levels[item.id])
                result.append({"key":"upgrade"+str(i),"name":item.name,"description":item.description,
                    "level_value":level,"level_max":int(item.max),"price":MonsterCatalog.upgrade_cost(item,level),
                    "full":level>=int(item.max),"action":"buy_"+str(i),"illustration":"upgrade","index":i,"kind":0})
        1:
            for i in range(2):
                var item = MonsterCatalog.MONSTERS[i]
                result.append({"key":"monster"+str(i),"name":item.name.to_upper(),
                    "description":"Seu primeiro monstro. Capture civis para aumentar a horda." if i==0 else "Civis capturados têm 30% de chance de virar esqueleto.",
                    "status":"NA COLEÇÃO","price":MonsterCatalog.SKIN_PRICES[i],"full":i in data.owned,
                    "action":"skin_"+str(i),"illustration":"monster","index":i,"kind":i})
        2:
            for item in MonsterCatalog.POWERS:
                result.append({"key":"power"+str(item.kind),"name":item.name,"description":item.description,
                    "status":"PODER TEMPORÁRIO","price":item.price,"full":item.kind in data.power_owned,
                    "action":"power_buy_"+str(item.kind),"illustration":"power","index":item.kind,"kind":item.kind})
            for i in range(MonsterCatalog.POWER_UPGRADES.size()):
                var item = MonsterCatalog.POWER_UPGRADES[i]
                var level = int(data.power_levels[item.id])
                result.append({"key":"powerupgrade"+str(i),"name":item.name,"description":("Super Fly: " if item.kind==3 else "Mascarado: ")+item.description,
                    "level_value":level,"level_max":int(item.max),"price":MonsterCatalog.upgrade_cost(item,level),
                    "full":level>=int(item.max),"locked":item.kind not in data.power_owned,
                    "badge":"SUPER FLY" if item.kind==3 else "MASCARADO",
                    "action":"power_upgrade_"+str(i),"illustration":"power_upgrade","index":i,"kind":item.kind})
        3:
            for i in range(MonsterCatalog.AREAS.size()):
                var item = MonsterCatalog.AREAS[i]
                result.append({"key":"area"+str(i),"name":item.name.to_upper(),"description":item.description,
                    "status":"NA ROTA" if i in data.areas else "REGIÃO DA FUGA","price":item.price,
                    "full":i in data.areas,"action":"area_"+str(i),"illustration":"area","index":i,"kind":0})
    return result

func sync_scroll(entries: Array[Dictionary], d: Dictionary) -> void:
    var rows = ceili(entries.size()/2.0)
    max_scroll = maxf(0,rows*(d.card_size.y+d.gap)-d.gap-d.grid.size.y)
    scroll = clampf(scroll,0,max_scroll)

func card_rect(index: int,d: Dictionary) -> Rect2:
    return Rect2(d.grid.position+Vector2((index%2)*(d.card_size.x+d.gap),floori(index/2.0)*(d.card_size.y+d.gap)-scroll),d.card_size)

func purchase_rect(rect: Rect2) -> Rect2:
    var width = minf(226,rect.size.x*.43)
    return Rect2(rect.end-Vector2(width+18,94),Vector2(width,76))

func scroll_by(delta: float) -> void:
    scroll = clampf(scroll+delta,0,max_scroll)

func action_at(g, point: Vector2) -> String:
    for i in range(g.buttons.size()-1,-1,-1):
        if g.buttons[i].rect.has_point(point):
            return str(g.buttons[i].action)
    return ""

func paint(g) -> void:
    var d = layout(g.full_rect())
    var entries = items(g.data)
    sync_scroll(entries,d)
    g.paint_target.draw_texture_rect(sprites.logo,d.title,false)
    var subtitle = ["Prepare a horda para ir mais longe.","Novos monstros para a sua coleção.","Transformações e suas melhorias.","Novas regiões para a próxima corrida."][category]
    g.home_menu.label(g,subtitle,Vector2(d.title.get_center().x,d.title.end.y+17),19,g.MINT,true,d.title.size.x+20)
    var wallet: Rect2 = d.wallet
    g.home_menu.slab(g,wallet,Color("24172f"),Color("b78b50"),15,4)
    g.scenery.sprite(g,g.art.items[1],wallet.position+Vector2(34,36+sin(g.ui_time*2)*1.1),46)
    g.home_menu.label(g,str(g.data.wallet),wallet.position+Vector2(68,49),38,g.GOLD,false,wallet.size.x-84)
    for i in range(4):
        var rect: Rect2 = d.tabs[i]
        var face = rect
        if g.pressed_button=="market_tab_"+str(i): face.position.y+=2
        if category==i:
            g.home_menu.slab(g,face.grow(2),Color("32203e"),g.GOLD,14,3)
        g.paint_target.draw_texture_rect(g.home_menu.panel_texture,face,false,Color.WHITE if category==i else Color(.68,.64,.83))
        var at = face.position+Vector2(50,face.size.y*.5)
        match i:
            0: g.home_menu.gear(g,at,23,g.ui_time*.08)
            1: g.scenery.sprite(g,g.home_menu.menu_zombie.face,at,50)
            2: g.scenery.sprite(g,sprites.potion,at,56)
            3: g.scenery.sprite(g,sprites.church,at,60)
        g.home_menu.label(g,TITLES[i],Vector2(face.position.x+89,face.get_center().y+10),26,g.GOLD if category==i else g.CREAM,false,face.size.x-105)
        g.buttons.append({"rect":rect,"action":"market_tab_"+str(i)})
    var back: Rect2 = d.back
    var back_face = back
    if g.pressed_button=="back": back_face.position.y+=2
    g.paint_target.draw_texture_rect(g.home_menu.panel_texture,back_face,false,Color(.76,.70,.89))
    var arrow = back_face.position+Vector2(50,back_face.size.y*.5)
    g.paint_target.draw_colored_polygon(PackedVector2Array([arrow+Vector2(9,-13),arrow+Vector2(-9,0),arrow+Vector2(9,13)]),g.CREAM)
    g.home_menu.label(g,"VOLTAR",back_face.get_center()+Vector2(19,10),27,g.CREAM,true,back_face.size.x-80)
    g.buttons.append({"rect":back,"action":"back"})
    if max_scroll>0:
        var rail = Rect2(d.grid.end.x+10,d.grid.position.y+5,6,d.grid.size.y-10)
        g.panel(rail,Color("24162e"),Color("65506f"),3,0,false)
        var thumb = maxf(42,rail.size.y*d.grid.size.y/(max_scroll+d.grid.size.y))
        g.panel(Rect2(rail.position+Vector2(0,(rail.size.y-thumb)*scroll/max_scroll),Vector2(6,thumb)),g.MINT,g.MINT,3,0,false)
        g.home_menu.label(g,"DESLIZE PARA VER MAIS",Vector2(d.grid.get_center().x,d.grid.end.y+27),15,g.MINT,true,d.grid.size.x)
    # Input areas are owned by the parent draw pass. The clipped child only paints.
    # Clearing the parent's controls can no longer erase the item controls.
    for i in range(entries.size()):
        var item = entries[i]
        if bool(item.full) or bool(item.get("locked",false)): continue
        var visible = purchase_rect(card_rect(i,d)).intersection(d.grid)
        if visible.size.x>40 and visible.size.y>=46:
            g.buttons.append({"rect":visible,"action":item.action})

func wrapped(g,value: String,point: Vector2,width: float,size: int,lines: int=3) -> void:
    var font: Font = g.home_menu.label_font
    var line = ""
    var row = 0
    for word in value.split(" "):
        var next = line+" "+word if not line.is_empty() else word
        if font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and not line.is_empty():
            g.home_menu.label(g,line,point+Vector2(0,row*(size+5)),size,g.MINT,false,width)
            row+=1
            if row>=lines: return
            line = word
        else: line = next
    if not line.is_empty() and row<lines:
        g.home_menu.label(g,line,point+Vector2(0,row*(size+5)),size,g.MINT,false,width)

func gem(g,point: Vector2,filled: bool) -> void:
    var vertices = PackedVector2Array()
    for i in range(6):
        vertices.append(point+Vector2.from_angle(-PI*.5+i*TAU/6)*9)
    g.paint_target.draw_colored_polygon(vertices,Color("8d789d"))
    var inner = PackedVector2Array()
    for p in vertices: inner.append(point+(p-point)*.72)
    g.paint_target.draw_colored_polygon(inner,Color("65eed5") if filled else Color("362441"))
    if filled:
        g.paint_target.draw_line(point+Vector2(-4,-2),point+Vector2(0,-5),Color("dcfff2"),2,true)

func illustration(g,item: Dictionary,p: Vector2,height: float) -> void:
    var bob = sin(g.ui_time*1.7+int(item.index)) * 1.4
    match item.illustration:
        "upgrade":
            if item.index==0:
                var portrait = g.home_menu.menu_zombie.face
                g.scenery.sprite(g.paint_target,portrait,p+Vector2(-height*.20,-height*.10),height*.66)
                g.scenery.sprite(g.paint_target,portrait,p+Vector2(-height*.01,-height*.02),height*.78)
                g.scenery.sprite(g.paint_target,portrait,p+Vector2(height*.19,height*.05),height*.91)
            else:
                var texture = g.art.items[5] if int(item.index) == 4 else sprites[["","shoe","magnet","potion"][item.index]]
                g.scenery.sprite(g.paint_target,texture,p+Vector2(0,bob),height,Color.WHITE,sin(g.ui_time*1.2)*.016)
        "monster":
            g.actor.paint(g.paint_target,item.kind,p+Vector2(0,height*.48),height,g.ui_time*.7,"idle",g.ui_time,0,Color.WHITE,false,1,false)
        "power":
            g.actor.paint(g.paint_target,item.kind,p+Vector2(0,height*.48),height,g.ui_time*.7,"fly" if item.kind==3 else "idle",g.ui_time,0,Color.WHITE,false,1,false)
        "area":
            var size = Vector2(height*1.16,height*.68)
            g.panel(Rect2(p-size*.5-Vector2(3,3),size+Vector2(6,6)),Color("23182e"),Color("92724d"),8,2,false)
            g.paint_target.draw_texture_rect(g.art.world_thumbnails[item.index],Rect2(p-size*.5,size),false)
        "power_upgrade":
            g.scenery.sprite(g.paint_target,g.art.rigs[item.kind][0],p-Vector2(7,height*.04),height*.80)
            var icon = [sprites.shoe,sprites.potion,g.art.items[7],g.art.items[2],sprites.potion,g.art.items[9]][item.index]
            g.scenery.sprite(g.paint_target,icon,p+Vector2(height*.25,height*.27),height*.43)

func purchase(g,item: Dictionary,rect: Rect2) -> void:
    var face = rect
    if g.pressed_button==item.action: face.position.y+=2
    var full = bool(item.full)
    var locked = bool(item.get("locked",false))
    g.paint_target.draw_texture_rect(g.home_menu.play_texture,face,false,Color(.46,.43,.57) if full or locked else Color.WHITE)
    if full or locked:
        var state = "BLOQUEADO" if locked else ("NO MÁXIMO" if item.has("level_value") else "LIBERADO")
        g.home_menu.label(g,state,face.get_center()+Vector2(0,8),19,g.CREAM if locked else g.MINT,true,face.size.x-30)
        return
    g.scenery.sprite(g.paint_target,g.art.items[1],face.position+Vector2(31,39),39)
    var text_center = Vector2(face.get_center().x+18,face.position.y)
    g.home_menu.label(g,"MELHORAR" if item.has("level_value") else "LIBERAR",text_center+Vector2(0,28),19,Color("3f211f"),true,face.size.x-62,false,1)
    g.home_menu.label(g,str(item.price) if int(item.price)>0 else "GRÁTIS",text_center+Vector2(0,59),30,g.CREAM,true,face.size.x-65,false,3)

func paint_rows(g) -> void:
    var d = layout(g.full_rect())
    var entries = items(g.data)
    sync_scroll(entries,d)
    for i in range(entries.size()):
        var item = entries[i]
        var rect = card_rect(i,d)
        if not rect.intersects(d.grid): continue
        g.paint_target.draw_style_box(g.home_menu.panel_style,rect)
        var text_x = rect.position.x+rect.size.x*.41
        var text_width = rect.end.x-text_x-18
        var title_size = int(clampf(rect.size.x*.056,21,29))
        g.home_menu.label(g,item.name,Vector2(text_x,rect.position.y+42),title_size,g.CREAM,false,text_width,false,3)
        wrapped(g,item.description,Vector2(text_x+1,rect.position.y+78),text_width-2,int(clampf(rect.size.x*.036,17,20)),3)
        var art_height = clampf(rect.size.x*.28,112,154)
        illustration(g,item,rect.position+Vector2(rect.size.x*.205,rect.size.y*.43),art_height)
        var baseline = rect.end.y-28
        if item.has("level_value"):
            g.home_menu.label(g,"NÍVEL "+str(item.level_value)+" / "+str(item.level_max),Vector2(rect.position.x+23,baseline),17,g.MINT,false,111)
            for j in range(int(item.level_max)):
                gem(g,Vector2(rect.position.x+140+j*23,baseline-6),j<int(item.level_value))
        else:
            g.home_menu.label(g,item.status,Vector2(rect.position.x+23,baseline),15,g.MINT,false,rect.size.x*.45-25)
        purchase(g,item,purchase_rect(rect))
