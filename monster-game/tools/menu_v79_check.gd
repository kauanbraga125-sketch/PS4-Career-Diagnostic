extends SceneTree

var failures: Array[String] = []
var game: Node2D
var output = OS.get_environment("HORDE_V79_OUTPUT")

func _initialize() -> void:
    call_deferred("run")

func check(value: bool, message: String) -> void:
    if not value: failures.append(message)

func redraw(time: float) -> void:
    game.ui_time = time
    game.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw

func run() -> void:
    game = load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.capture_freeze = true
    game.sound.set_enabled(false)
    game.data = MonsterCatalog.defaults()
    game.data.wallet = 4517
    game.data.player_level = 8
    game.data.level_souls = 189
    game.data.best = 5571
    game.data.best_souls = 119
    game.data.ritual_progress = 38
    game.ritual_view = {}
    check(game.actor.zombie is HordeZombieSprite,"0.7.8 full-frame game renderer is preserved")
    check(game.actor.zombie.stride_run != null,"0.7.8 drawn run is preserved")
    for size in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(1600,900)]:
        root.size = size
        await process_frame
        game.configure_layout()
        await redraw(2.0)
        var d = game.home_menu.layout(game.full_rect())
        check(not d.play.intersects(d.ritual),"Play and ritual overlap at "+str(size))
        check(not d.play.intersects(d.nav),"Play and navigation overlap at "+str(size))
        check(not d.level.intersects(d.wallet),"Header overlap at "+str(size))
        for i in range(3):
            check(d.tabs[i].size.y>=60,"Navigation target too small")
            for j in range(i):check(not d.tabs[i].intersects(d.tabs[j]),"Navigation targets overlap")
        if not output.is_empty():
            root.get_texture().get_image().save_png(output+"/menu-"+str(size.x)+"x"+str(size.y)+".png")
    root.size=Vector2i(1600,720)
    await process_frame
    game.configure_layout()
    for sample in [{"name":"neutro","time":2.0},{"name":"piscada","time":3.69},{"name":"olhar","time":10.0},{"name":"sorriso","time":16.5},{"name":"esquerda","time":24.0},{"name":"raiva","time":35.9}]:
        await redraw(float(sample.time))
        var sprite: Sprite2D = game.home_menu.menu_zombie.sprites[0]
        check(sprite.visible,"Menu zombie is not visible")
        check(sprite.region_rect.size==Vector2(512,512),"A sprite uses a changing crop")
        if not output.is_empty():root.get_texture().get_image().save_png(output+"/menu-"+sample.name+".png")
    for action in ["market","collection","missions","settings","help"]:
        game.change_screen("home")
        await redraw(2)
        var action_rect=Rect2()
        for button in game.buttons:
            if button.action==action:action_rect=button.rect
        check(action_rect.size.length()>0,"Missing button "+action)
        game.press_at(action_rect.get_center(),7)
        await process_frame
        await RenderingServer.frame_post_draw
        check(game.screen!="home","Button did not navigate: "+action)
        check(not game.home_menu.menu_zombie.sprites[0].visible,"Menu sprite leaks over another screen")
        game.release_touch(7)
    game.change_screen("home")
    await redraw(2)
    var play=game.home_menu.layout(game.full_rect()).play
    game.press_at(play.get_center(),8)
    await process_frame
    await RenderingServer.frame_post_draw
    check(game.screen=="run","Play did not start the game")
    game.release_touch(8)
    check(not game.home_menu.menu_zombie.sprites[0].visible,"Menu sprite leaks into gameplay")
    if not output.is_empty():root.get_texture().get_image().save_png(output+"/gameplay.png")
    if failures.is_empty():print("MENU_V79_OK: responsive layout, six actions, touch navigation, menu visibility and 0.7.8 gameplay renderer")
    else:
        for failure in failures:push_error("MENU_V79_FAIL: "+failure)
    var status=0 if failures.is_empty() else 1
    stop_audio(game)
    await create_timer(.12).timeout
    game.queue_free()
    await process_frame
    game=null
    quit(status)

func stop_audio(node: Node) -> void:
    if node is AudioStreamPlayer:
        node.stop()
        node.stream=null
    for child in node.get_children():stop_audio(child)
