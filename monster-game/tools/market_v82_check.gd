extends SceneTree

var game: Node2D
var failures: Array[String] = []
var output = OS.get_environment("HORDE_MARKET_OUTPUT")

func _initialize() -> void:
    call_deferred("run")

func check(value: bool,message: String) -> void:
    if not value:
        failures.append(message)
        push_error("MARKET_V82_FAIL: "+message)

func frames(count: int=4) -> void:
    for i in range(count):
        await process_frame
        await RenderingServer.frame_post_draw

func action_rect(action: String) -> Rect2:
    for button in game.buttons:
        if str(button.action)==action: return button.rect
    return Rect2()

func touch(point: Vector2,pressed: bool,id: int=7) -> void:
    var event = InputEventScreenTouch.new()
    event.position = game.to_global(point)
    event.pressed = pressed
    event.index = id
    game._input(event)

func drag(point: Vector2,id: int=7) -> void:
    var event = InputEventScreenDrag.new()
    event.position = game.to_global(point)
    event.index = id
    game._input(event)

func tap(action: String) -> void:
    var rect = action_rect(action)
    check(rect.size.x>0,"Missing visible touch target "+action)
    if rect.size.x<=0: return
    var balance = int(game.data.wallet)
    touch(rect.get_center(),true)
    await frames(5)
    check(int(game.data.wallet)==balance,"Purchase occurred before releasing touch: "+action)
    touch(rect.get_center(),false)
    await frames()

func capture(name: String) -> void:
    if not output.is_empty(): root.get_texture().get_image().save_png(output+"/"+name+".png")

func buy_and_check(action: String,price: int) -> void:
    var before = int(game.data.wallet)
    await tap(action)
    check(int(game.data.wallet)==before-price,"Incorrect debit for "+action)

func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.capture_mode = true
    game.set_physics_process(false)
    game.sound.set_enabled(false)
    game.data = MonsterCatalog.defaults()
    game.data.wallet = 4835
    game.data.levels.horde = 1
    game.open_market()
    await frames(10)
    check(game.buttons.size()==9,"Item controls vanished during redraw; expected 4 purchases + 4 categories + Back")
    for size in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1280,960)]:
        root.size = size
        await frames()
        var d = game.market.layout(game.full_rect())
        check(game.market.items(game.data).size()==4,"Metamorfose missing from upgrade category")
        for i in range(4):
            var rect = action_rect("buy_"+str(i))
            check(rect.size.y>=60,"Small or missing purchase button at "+str(size))
            check(d.grid.encloses(rect),"Purchase target outside the visible grid")
            for j in range(i):check(not rect.intersects(action_rect("buy_"+str(j))),"Purchase buttons overlap")
        capture("mercado-"+str(size.x)+"x"+str(size.y))
    root.size = Vector2i(1600,720)
    await frames()
    for tab in range(1,4):
        await tap("market_tab_"+str(tab))
        check(game.market.category==tab,"Category touch did not navigate")
        capture("categoria-"+str(tab))
    await tap("market_tab_0")
    await buy_and_check("buy_0",1400)
    check(int(game.data.levels.horde)==2,"Horde upgrade not granted")
    await buy_and_check("buy_1",420)
    await buy_and_check("buy_2",360)
    await buy_and_check("buy_3",500)
    check(int(game.data.levels.jump)==1 and int(game.data.levels.magnet)==1 and int(game.data.levels.perk)==1,"An upgrade was charged without being applied")
    var logic = HordeRun.new()
    logic.start(game.data.levels,123,0,game.data.areas,game.data.owned,[3,2],{})
    logic.activate_perk(3)
    check(is_equal_approx(logic.perk_left,10.0),"Metamorfose bonus not applied to Fly")
    logic.activate_perk(2)
    check(is_equal_approx(logic.perk_left,10.0),"Metamorfose bonus not applied to Mask")
    game.data.wallet = 20000
    await frames()
    await buy_and_check("buy_0",3150)
    check(int(game.data.levels.horde)==3,"Maximum level not reached")
    check(action_rect("buy_0").size==Vector2.ZERO,"Maxed upgrade still accepts a purchase")
    var full_balance = int(game.data.wallet)
    var max_button = game.market.purchase_rect(game.market.card_rect(0,game.market.layout(game.full_rect())))
    touch(max_button.get_center(),true)
    await frames()
    touch(max_button.get_center(),false)
    await frames()
    check(int(game.data.wallet)==full_balance,"Maxed upgrade charged twice")
    game.data.wallet = 0
    await frames()
    await tap("buy_1")
    check(game.data.wallet==0 and game.data.levels.jump==1,"Insufficient-funds purchase changed data")
    check(game.toast.begins_with("Faltam "),"Missing insufficient-funds feedback")
    game.data.wallet = 50000
    await frames()
    # A second finger cannot take over an active purchase or cause a second charge.
    var at = action_rect("buy_1").get_center()
    var single_balance = int(game.data.wallet)
    var single_cost = MonsterCatalog.upgrade_cost(MonsterCatalog.UPGRADES[1],1)
    touch(at,true,7)
    touch(at,true,8)
    await frames()
    touch(at,false,8)
    touch(at,false,7)
    await frames()
    check(int(game.data.wallet)==single_balance-single_cost and int(game.data.levels.jump)==2,"Multi-touch caused duplicate or lost purchase")
    await tap("market_tab_1")
    await buy_and_check("skin_1",1000)
    check(1 in game.data.owned,"Purchased skeleton not unlocked")
    await tap("market_tab_2")
    check(action_rect("power_upgrade_1").size==Vector2.ZERO,"Locked masked upgrade is purchasable")
    await buy_and_check("power_buy_2",2800)
    check(2 in game.data.power_owned,"Masked power not unlocked")
    await buy_and_check("power_upgrade_0",500)
    await buy_and_check("power_upgrade_1",500)
    check(game.data.power_levels.fly_time==1 and game.data.power_levels.mask_time==1,"Power time upgrades not applied")
    # Starting a swipe on a live purchase button must scroll without buying.
    var drag_start = action_rect("power_upgrade_0").get_center()
    var drag_balance = int(game.data.wallet)
    touch(drag_start,true)
    await frames()
    drag(drag_start-Vector2(0,110))
    await frames()
    touch(drag_start-Vector2(0,110),false)
    await frames()
    check(int(game.data.wallet)==drag_balance,"Dragging triggered an accidental purchase")
    check(game.market.scroll>0,"Touch drag did not scroll the power grid")
    for i in range(3):
        var grid: Rect2 = game.market.layout(game.full_rect()).grid
        var start = grid.get_center()+Vector2(0,grid.size.y*.30)
        touch(start,true)
        drag(start-Vector2(0,grid.size.y*.65))
        await frames()
        touch(start-Vector2(0,grid.size.y*.65),false)
        await frames()
    check(is_equal_approx(game.market.scroll,game.market.max_scroll),"Could not reach the final power upgrades")
    check(action_rect("power_upgrade_0").size==Vector2.ZERO,"Offscreen purchase target remains active")
    capture("poderes-rolagem")
    await buy_and_check("power_upgrade_5",2500)
    check(game.data.power_levels.mask_revive==1,"Final scrolled power not purchased")
    await tap("market_tab_3")
    await buy_and_check("area_2",2200)
    await buy_and_check("area_3",3800)
    check(2 in game.data.areas and 3 in game.data.areas,"Purchased scenarios missing from route")
    check(game.save_game("user://market-v82-check.json"),"Could not persist purchase test")
    var saved = JSON.parse_string(FileAccess.get_file_as_string("user://market-v82-check.json"))
    var loaded = game.validate_save(saved)
    check(loaded.levels==game.data.levels and loaded.power_levels==game.data.power_levels,"Upgrade levels changed after reloading save")
    check(loaded.wallet==game.data.wallet and loaded.owned==game.data.owned and loaded.areas==game.data.areas and loaded.power_owned==game.data.power_owned,"Purchase balance or ownership not persisted")
    logic.start(loaded.levels,123,0,loaded.areas,loaded.owned,loaded.power_owned,loaded.power_levels)
    logic.activate_perk(3)
    check(is_equal_approx(logic.perk_left,13.0),"Shared and specific duration bonuses do not combine correctly")
    await tap("back")
    check(game.screen=="home","Back did not return to the menu")
    capture("menu-preservado")
    var play: Rect2 = game.home_menu.layout(game.full_rect()).play
    game.press_at(play.get_center(),9)
    game.release_touch(9)
    await frames()
    check(game.screen=="run","Could not enter gameplay from updated menu")
    check(not game.home_menu.menu_zombie.sprites[0].visible,"Menu sprite leaked into gameplay")
    if failures.is_empty():
        print("MARKET_V82_OK: rendered controls persist across frames; touch purchases and exact debits; all four upgrades; maximum level; insufficient funds; multi-touch; monster/power/scenario unlocks; drag without purchase; scrolling/clipping; save reload; duration bonuses; menu and Play")
    game.set_process(false)
    game.sound.set_process(false)
    stop_audio(game)
    game.queue_free()
    await process_frame
    await process_frame
    game = null
    quit(0 if failures.is_empty() else 1)

func stop_audio(node: Node) -> void:
    if node is AudioStreamPlayer:
        node.stop()
        node.stream = null
    for child in node.get_children(): stop_audio(child)
