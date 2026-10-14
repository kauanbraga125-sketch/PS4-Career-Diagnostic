class_name StreetControls
extends Node

var game
var move=Vector2.ZERO
var look_delta=Vector2.ZERO
var joystick=Vector2.ZERO
var move_id=-1
var look_id=-1
var fingers: Dictionary={}
var states: Dictionary={}
var presses: Dictionary={}
var mobile=OS.has_feature("android") or OS.has_feature("ios")

func areas() -> Dictionary:
	var a={"enter":Rect2(1030,575,100,76),"pause":Rect2(1206,24,50,48),"map":Rect2(24,26,190,160)}
	if game and game.player and game.player.vehicle:
		a.merge({"accelerate":Rect2(1146,450,110,98),"brake":Rect2(1146,570,110,90),"reverse":Rect2(915,575,96,76)})
		if game.player.vehicle is StreetAircraft: a.merge({"climb":Rect2(1030,344,100,82),"descend":Rect2(1146,344,110,82)})
	else:
		a.merge({"aim":Rect2(1030,426,100,84),"fire":Rect2(1146,426,110,100),"jump":Rect2(1146,575,110,76),"reload":Rect2(915,426,96,70),"weapon":Rect2(915,575,96,76),"sprint":Rect2(245,474,94,66)})
		if game and game.player and not game.player.is_on_floor(): a["parachute"]=Rect2(990,324,218,70)
	return a

func held(action: String) -> bool:
	var keys={"brake":KEY_SPACE,"sprint":KEY_SHIFT,"accelerate":KEY_W,"reverse":KEY_S,"climb":KEY_SHIFT,"descend":KEY_CTRL}
	if action in keys: return states.get(action,false) or Input.is_physical_key_pressed(keys[action])
	if action=="fire": return states.get(action,false) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
	if action=="aim": return states.get(action,false) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
	return states.get(action,false)

func consume(action: String) -> bool:
	var value=presses.get(action,false)
	presses.erase(action)
	return value

func clear() -> void:
	states.clear();presses.clear();fingers.clear()
	move_id=-1;look_id=-1;joystick=Vector2.ZERO;move=Vector2.ZERO;look_delta=Vector2.ZERO

func _process(_dt: float) -> void:
	if not game or not game.running:
		move=Vector2.ZERO
		return
	var keys=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	move=(keys+joystick).limit_length()

func _input(event: InputEvent) -> void:
	if not game or not game.hud: return
	var factor=game.hud.ui_scale()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:
			game.toggle_pause()
			return
		if not game.running: return
		var binding={KEY_E:"enter",KEY_SPACE:"jump",KEY_R:"reload",KEY_TAB:"weapon",KEY_M:"map",KEY_Q:"briefing",KEY_P:"parachute"}
		if binding.has(event.physical_keycode): presses[binding[event.physical_keycode]]=true
	if event is InputEventMouseMotion and game.running and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: look_delta+=event.relative*.0025
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not game.running or game.hud.map_open: game.hud.menu_click(event.position/factor)
		elif Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if event is InputEventScreenTouch:
		var p=event.position/factor
		if not event.pressed:
			if event.index==move_id: move_id=-1;joystick=Vector2.ZERO
			if event.index==look_id: look_id=-1
			if fingers.has(event.index):
				var action=fingers[event.index]
				fingers.erase(event.index)
				states[action]=action in fingers.values()
			return
		if not game.running or game.hud.map_open:
			game.hud.menu_click(p)
			return
		for action in areas():
			if areas()[action].has_point(p):
				states[action]=true;presses[action]=true;fingers[event.index]=action
				return
		if p.x<380 and p.y>390 and move_id<0:
			move_id=event.index
			joystick=((p-Vector2(155,570))/74).limit_length()
		elif look_id<0: look_id=event.index
	if event is InputEventScreenDrag and game.running:
		if event.index==move_id: joystick=((event.position/factor-Vector2(155,570))/74).limit_length()
		if event.index==look_id or fingers.get(event.index,"") in ["aim","fire"]: look_delta+=event.relative/factor*.0032
