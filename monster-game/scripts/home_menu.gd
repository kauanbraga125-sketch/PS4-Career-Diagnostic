class_name HordeHomeMenu
extends RefCounted

# The approved illustration guides composition. All controls, labels, actors,
# the ritual and its feedback remain independent, live game elements.
const INK = Color("20132f")
const IVORY = Color("fff0cc")
const GOLD = Color("ffc464")
const MINT = Color("8fe7c9")
var logo_font: Font = preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
var label_font: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")

func layout(view: Rect2) -> Dictionary:
    var margin = maxf(24,view.size.x*.024)
    var left = view.position.x+margin
    var right = view.end.x-margin
    var top = view.position.y+22
    var nav = Rect2(left,view.end.y-114,right-left,96)
    var right_width = minf(460,view.size.x*.32)
    var play = Rect2(right-right_width,nav.position.y-120,right_width,94)
    var altar_height = clampf((play.position.y-top-148)*.79,172,275)
    var altar = Vector2(play.get_center().x,play.position.y-98-altar_height*.35)
    var ritual = Rect2(play.position.x+14,play.position.y-94,play.size.x-28,72)
    var stage_bottom = nav.position.y-44
    var stage_height = clampf((stage_bottom-top-150)*.86,225,338)
    var wallet = Rect2(right-290,top,154,59)
    var level = Rect2(left+view.size.x*.31,top,minf(view.size.x*.29,wallet.position.x-left-view.size.x*.31-18),62)
    var result = {"view":view,"title":Rect2(left+6,top+4,view.size.x*.285,132),
        "level":level,"wallet":wallet,"audio":Rect2(right-120,top,55,59),"help":Rect2(right-55,top,55,59),
        "nav":nav,"play":play,"ritual":ritual,"altar":altar,"altar_height":altar_height,
        "stage_bottom":stage_bottom,"stage_height":stage_height,
        "record":Rect2(left,nav.position.y-37,minf(390,play.position.x-left-28),28)}
    var tabs: Array[Rect2] = []
    for i in range(3):
        tabs.append(Rect2(nav.position.x+i*nav.size.x/3+3,nav.position.y+3,nav.size.x/3-6,nav.size.y-6))
    result.tabs=tabs
    return result

func label(g,value: String,baseline: Vector2,size: int,color: Color=IVORY,center: bool=true,max_width: float=-1,title: bool=false,outline: int=2) -> void:
    var font=logo_font if title else label_font
    if max_width>0:
        while size>13 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>max_width: size-=1
    var point=baseline
    if center: point.x-=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x*.5
    g.paint_target.draw_string_outline(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,outline,INK)
    g.paint_target.draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func shape(rect: Rect2,cut: float=10) -> PackedVector2Array:
    var p=rect.position
    var e=rect.end
    return PackedVector2Array([p+Vector2(cut,0),Vector2(e.x-cut,p.y),Vector2(e.x,p.y+cut),
        e-Vector2(0,cut),e-Vector2(cut,0),Vector2(p.x+cut,e.y),Vector2(p.x,e.y-cut),p+Vector2(0,cut)])

func slab(g,rect: Rect2,face: Color,border: Color,cut: float=10,depth: float=5) -> void:
    var back=rect
    back.position.y+=depth
    g.paint_target.draw_colored_polygon(shape(back,cut),Color("130d21"))
    g.paint_target.draw_colored_polygon(shape(rect,cut),border)
    g.paint_target.draw_colored_polygon(shape(rect.grow(-2),maxf(1,cut-2)),face)
    g.paint_target.draw_line(rect.position+Vector2(cut+4,5),Vector2(rect.end.x-cut-4,rect.position.y+5),Color(1,.9,.7,.18),2,true)
    g.paint_target.draw_line(Vector2(rect.position.x+cut+4,rect.end.y-5),rect.end-Vector2(cut+4,5),Color(0,0,0,.16),3,true)

func register(g,rect: Rect2,action: String) -> void:
    g.buttons.append({"rect":rect,"action":action})

func header(g,d: Dictionary) -> void:
    var title: Rect2=d.title
    var font_size=int(clampf(title.size.x*.19,62,80))
    var line1=title.position+Vector2(0,font_size)
    var line2=line1+Vector2(0,font_size*.87)
    label(g,"NOITE",line1+Vector2(2,7),font_size,Color("a7663d"),false,title.size.x,true,8)
    label(g,"NOITE",line1,font_size,IVORY,false,title.size.x,true,5)
    label(g,"DA HORDA",line2+Vector2(2,7),int(font_size*.82),Color("9d572d"),false,title.size.x,true,7)
    label(g,"DA HORDA",line2,int(font_size*.82),GOLD,false,title.size.x,true,4)
    var level: Rect2=d.level
    g.panel(level,Color(.10,.055,.17,.89),Color("79627e"),15,2,false)
    g.animated_soul(level.position+Vector2(30,32+sin(g.ui_time*2.1)*2),43,g.ui_time)
    label(g,"NÍVEL "+str(g.data.player_level),level.position+Vector2(63,27),24,IVORY,false,level.size.x*.47)
    var count=str(g.data.level_souls)+" / "+str(HordeProgress.level_target(int(g.data.player_level)))
    var count_size=20
    while label_font.get_string_size(count,HORIZONTAL_ALIGNMENT_LEFT,-1,count_size).x>level.size.x*.34 and count_size>13: count_size-=1
    label(g,count,Vector2(level.end.x-14-label_font.get_string_size(count,HORIZONTAL_ALIGNMENT_LEFT,-1,count_size).x,level.position.y+28),count_size,MINT,false)
    g.progress_bar(Rect2(level.position+Vector2(62,41),Vector2(level.size.x-78,9)),float(g.data.level_souls)/HordeProgress.level_target(int(g.data.player_level)),MINT)
    g.panel(d.wallet,Color(.10,.055,.17,.94),Color("98735b"),23,2,false)
    g.floating_item(1,d.wallet.position+Vector2(29,30),39)
    label(g,str(g.data.wallet),d.wallet.position+Vector2(56,40),32,GOLD,false,d.wallet.size.x-68)
    for action in ["audio","help"]:
        var rect: Rect2=d[action]
        var center=rect.get_center()
        g.panel(rect,Color("483054") if rect.has_point(g.get_local_mouse_position()) else Color("2b1c3b"),Color("a27f79"),26,2,false)
        register(g,rect,"settings" if action=="audio" else "help")
        if action=="help":label(g,"?",center+Vector2(0,14),37,IVORY,true)
        else:gear(g,center,18,g.ui_time*.35)

func gear(g,point: Vector2,radius: float,time: float) -> void:
    var vertices=PackedVector2Array()
    for i in range(48):
        var angle=time+i*TAU/48
        var r=radius*(1 if i%6 in [1,2,3,4] else .76)
        vertices.append(point+Vector2(cos(angle),sin(angle))*r)
    g.paint_target.draw_colored_polygon(vertices,IVORY)
    g.draw_circle(point,radius*.50,Color("2b1c3b"))
    g.draw_arc(point,radius*.51,0,TAU,32,GOLD,2,true)

func formation(owned: Array) -> Array[Dictionary]:
    var kinds: Array=[]
    for kind in owned:
        if int(kind) in [0,1] and kind not in kinds:kinds.append(kind)
    if kinds.is_empty():kinds=[0]
    if kinds.size()==1:return [{"kind":kinds[0],"x":.49,"depth":0.0,"height":1.0,"phase":0.0}]
    var result: Array[Dictionary]=[]
    for row in range(2):
        var count=4 if row==0 else 3
        for i in range(count):
            result.append({"kind":kinds[(i+row)%kinds.size()],"x":(.12+i*.76/(count-1)) if row==0 else (.23+i*.54/(count-1)),"depth":-105.0 if row==0 else 0.0,"height":.64 if row==0 else .84,"phase":i*.7+row*.4})
    return result

func cast(g,d: Dictionary) -> void:
    var view: Rect2=d.view
    var width=view.size.x*.60
    var left=view.position.x+22
    var height: float=d.stage_height
    var floor_y: float=d.stage_bottom-18
    for member in formation(g.data.owned):
        var p=Vector2(left+width*float(member.x),floor_y+float(member.depth))
        var h=height*float(member.height)
        g.draw_set_transform(p+Vector2(0,4),0,Vector2(h*.24,6))
        g.draw_circle(Vector2.ZERO,1,Color(.025,.013,.05,.40));g.draw_set_transform(Vector2.ZERO)
        g.actor.paint(g,int(member.kind),p,h,g.ui_time*.5+float(member.phase),"idle",g.ui_time+float(member.phase),0,Color.WHITE,false,1.0,false)
    # The starting cast is the zombie and its available fly form.
    if 3 in g.data.power_owned:
        var p=Vector2(left+width*.82,floor_y-height*.52+sin(g.ui_time*2.5)*9)
        g.actor.paint(g,3,p+Vector2(0,height*.30),height*.51,g.ui_time*1.4,"fly",g.ui_time,0,Color.WHITE,false,1,false)

func altar(g,d: Dictionary) -> void:
    var p: Vector2=d.altar
    var h: float=d.altar_height
    paint_cauldron(g,p,h)
    for i in range(4):
        var t=g.ui_time*1.2+i*TAU/4
        g.animated_soul(p+Vector2(cos(t)*h*.29,-h*.33+sin(t)*h*.10),33+sin(t*1.5)*3,g.ui_time+i*.29,Color(1,1,1,.86))
    var rect: Rect2=d.ritual
    slab(g,rect,Color("261b35"),Color("8b7378"),13,3)
    label(g,"RITUAL DA MADRUGADA",rect.position+Vector2(rect.size.x*.5,23),22,IVORY,true,rect.size.x-24)
    var amount=float(g.data.ritual_progress)
    if not g.ritual_view.is_empty() and g.ritual_time<2.5:
        amount=fposmod(float(g.ritual_view.old_progress)+float(g.ritual_view.points)*clampf(g.ritual_time/2.1,0,1),100)
    g.progress_bar(Rect2(rect.position+Vector2(15,33),Vector2(rect.size.x-30,14)),amount/100,MINT)
    label(g,str(int(amount))+" / 100",rect.position+Vector2(rect.size.x*.5,65),20,IVORY,true)
    if not g.ritual_view.is_empty() and int(g.ritual_view.coins)>0 and g.ritual_time>1.7:
        label(g,"+"+str(g.ritual_view.coins)+" MOEDAS",p-Vector2(0,h*.6),22,GOLD,true,rect.size.x)

func paint_cauldron(g,p: Vector2,h: float) -> void:
    var receiving=not g.ritual_view.is_empty() and g.ritual_time<2.7 and int(g.ritual_view.get("points",0))>0
    var pulse=pow(maxf(0,sin(g.ui_time*(9 if receiving else 2.3))),2)
    var power=1.0+(1.5*pulse if receiving else .2*pulse)
    g.draw_set_transform(p+Vector2(0,9),0,Vector2(h*.70,h*.30))
    g.draw_circle(Vector2.ZERO,1,Color(.15,1,.75,.07*power));g.draw_set_transform(Vector2.ZERO)
    g.scenery.sprite(g,g.art.ritual[1],p,h,Color(1,1,1,1),sin(g.ui_time*1.9)*(.013 if receiving else .005))
    var liquid=p-Vector2(0,h*.168)
    var rx=h*.267;var ry=h*.059
    g.draw_set_transform(liquid,0,Vector2(rx,ry))
    g.draw_circle(Vector2.ZERO,1,Color("127d77"));g.draw_set_transform(Vector2.ZERO)
    var wave=PackedVector2Array()
    for i in range(33):
        var x=-1+i/16.0
        wave.append(liquid+Vector2(x*rx,ry*.25*sin(x*8+g.ui_time*3.2)*sqrt(maxf(0,1-x*x))))
    for i in range(32,-1,-1):
        var x=-1+i/16.0
        wave.append(liquid+Vector2(x*rx,ry*sqrt(maxf(0,1-x*x))))
    g.paint_target.draw_colored_polygon(wave,Color(.11,.91,.67,.88))
    for i in range(3):
        var age=fposmod(g.ui_time*.7+i*.33,1)
        g.draw_set_transform(liquid+Vector2(sin(g.ui_time+i)*rx*.17,0),0,Vector2(1,.22))
        g.draw_arc(Vector2.ZERO,rx*age,0,TAU,36,Color(.65,1,.80,(1-age)*.65),1.7,true)
        g.draw_set_transform(Vector2.ZERO)
    for i in range(8):
        var age=fposmod(g.ui_time*(.55 if not receiving else .95)+i*.137,1)
        var origin=liquid+Vector2(sin(i*7.9)*rx*.73,cos(i*2.1)*ry*.4)
        var at=origin-Vector2(sin(age*4+i)*3,age*h*.115)
        var radius=(2+sin(i*3.3)*.9)*h/210
        if age<.76:
            g.draw_circle(at,radius*(.6+age),Color(.56,1,.79,.65))
            g.draw_arc(at,radius*(.6+age),0,TAU,12,Color(.86,1,.87,.7),1,true)
        else:
            for j in range(4):
                var direction=Vector2.from_angle(j*TAU/4+i)
                g.paint_target.draw_line(at+direction*radius,at+direction*(radius+6*(age-.76)/.24),Color(.65,1,.85,(1-age)*3),1.3,true)
    for i in range(5):
        var age=fposmod(g.ui_time*.23+i*.21,1)
        var at=liquid+Vector2(sin(age*5+i)*h*.12,-age*h*.38)
        g.draw_circle(at,h*(.025+age*.045),Color(.40,1,.78,sin(age*PI)*.055*power))

func play(g,d: Dictionary) -> void:
    var rect: Rect2=d.play
    var face=rect
    if g.pressed_button=="play": face.position.y+=3
    slab(g,face,Color("f1a52e") if rect.has_point(g.get_local_mouse_position()) else Color("e79327"),Color("ffd574"),14,7)
    slab(g,face.grow(-8),Color("e9a03a"),Color("ae601f"),8,0)
    g.paint_target.draw_line(face.position+Vector2(22,14),Vector2(face.end.x-22,face.position.y+14),Color(1,.86,.48,.6),2,true)
    var triangle=face.position+Vector2(41,face.size.y*.5)
    g.paint_target.draw_colored_polygon(PackedVector2Array([triangle+Vector2(-12,-19),triangle+Vector2(17,0),triangle+Vector2(-12,19)]),INK)
    g.paint_target.draw_colored_polygon(PackedVector2Array([triangle+Vector2(-9,-15),triangle+Vector2(12,0),triangle+Vector2(-9,15)]),IVORY)
    label(g,"JOGAR",face.get_center()+Vector2(21,19),50,IVORY,true,face.size.x-90,true,4)
    register(g,rect,"play")

func nav_icon(g,index: int,point: Vector2) -> void:
    match index:
        0:
            g.scenery.sprite(g,g.art.rigs[1][5],point-Vector2(10,0),39,Color.WHITE,.65)
            var p=point+Vector2(17,1)
            g.paint_target.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-19),p+Vector2(13,-4),p+Vector2(5,-4),p+Vector2(5,16),p+Vector2(-5,16),p+Vector2(-5,-4),p+Vector2(-13,-4)]),MINT)
        1:
            g.scenery.sprite(g,g.art.power(3,g.ui_time),point,49)
        2:
            for i in range(3):
                g.scenery.sprite(g,g.art.rigs[[0,1,2][i]][0],point+Vector2((i-1)*22,abs(i-1)*3),35)
        3:
            g.panel(Rect2(point-Vector2(14,20),Vector2(28,41)),Color("657583"),Color("a59fab"),12,2,false)
            g.paint_target.draw_line(point+Vector2(0,-12),point+Vector2(0,9),GOLD,3,true)
            g.paint_target.draw_line(point+Vector2(-7,-5),point+Vector2(7,-5),GOLD,3,true)
            g.paint_target.draw_line(point+Vector2(-26,18),point+Vector2(26,18),Color("8ca490"),4,true)
        4:
            g.panel(Rect2(point-Vector2(19,21),Vector2(38,42)),Color("e6bf79"),Color("a46f42"),5,2,false)
            for j in range(3): g.paint_target.draw_line(point+Vector2(-10,-10+j*10),point+Vector2(10,-10+j*10),Color("61464c"),2,true)
            g.paint_target.draw_line(point+Vector2(-21,-21),point+Vector2(23,-21),GOLD,5,true)
            g.paint_target.draw_line(point+Vector2(-21,21),point+Vector2(23,21),GOLD,5,true)

func navigation(g,d: Dictionary) -> void:
    var titles=["MERCADO","COLEÇÃO","MISSÕES"]
    var actions=["market","collection","missions"]
    slab(g,d.nav,Color("22172f"),Color("786078"),12,4)
    for i in range(3):
        var rect: Rect2=d.tabs[i]
        var hover=rect.has_point(g.get_local_mouse_position())
        slab(g,rect,Color("45304e") if hover else Color("33233f"),Color("aa8162") if hover else Color("725568"),9,0)
        var point=rect.get_center()+Vector2(-68,-2+sin(g.ui_time*2+i)*2)
        if i==0:g.scenery.sprite(g,g.art.ritual[2],point,56,Color.WHITE,sin(g.ui_time*1.8)*.035)
        elif i==1:
            for j in range(2):g.scenery.sprite(g,g.art.rigs[0 if j==0 or 1 not in g.data.owned else 1][0],point+Vector2(j*21-12,-2),39)
        else:nav_icon(g,4,point)
        label(g,titles[i],rect.get_center()+Vector2(30,11),28,GOLD,true,rect.size.x-115)
        register(g,rect,actions[i])
    g.panel(d.record,Color(.10,.06,.17,.87),Color("745668"),10,1,false)
    label(g,"RECORDE: "+str(g.data.best_souls)+" ALMAS  •  "+str(g.data.best)+" M",d.record.position+Vector2(13,20),18,GOLD,false,d.record.size.x-22)

func paint(g) -> void:
    var d=layout(g.full_rect())
    header(g,d)
    cast(g,d)
    altar(g,d)
    play(g,d)
    navigation(g,d)
    g.effects.paint(g,g.art,g.actor)

func ritual_target(view: Rect2) -> Vector2:
    return layout(view).altar-Vector2(0,18)
