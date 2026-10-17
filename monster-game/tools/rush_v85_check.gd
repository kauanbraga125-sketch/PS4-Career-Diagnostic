extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func isolated(count: int, speed: float) -> HordeRun:
	var r = HordeRun.new();r.start({}, 85);r.entities.clear();r.tunnels.clear();r.next_segment = 99999;r.next_rush_world = 1e12
	r.world_px = maxf(0,(speed-305)*230);r.speed = speed;r.cruise_speed = speed;r.last_effective_speed = speed
	r.terrain.segments.assign([{"start":-1e12,"end":1e12,"height":0.0,"state":0}])
	while r.members.size() < count:r.add_member(0,false)
	return r
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error("RUSH_V85: "+message)
func run() -> void:
	for fps in [30,60,120]:
		for speed in [305.0,500.0,780.0]:
			for count in [1,5,20]:
				var r = isolated(count,speed)
				var e = r.spawn_rushing_car(1300,0)
				e.x = HordeRun.ANCHOR+(speed-e.vx)*0.4+float(e.width)*0.5+18
				r.jump()
				for frame in range(int(fps*2.5)):r.advance(1.0/fps,frame<float(fps)*0.5)
				check(r.active_count()==count and r.losses==0,"jump against incoming car "+str([fps,speed,count,r.losses]))
	var r = isolated(1,305)
	var deferred = r.spawn_rushing_car(6000,1,true)
	r.advance(1.0/60,false);check(deferred.vx==0 and not deferred.warned,"car started before approach")
	deferred.x = 1100;r.advance(1.0/60,false)
	check(deferred.vx<0 and not deferred.rush_waiting and deferred.warned,"approach/warning did not start")
	print("RUSH_V85_RESULT: "+JSON.stringify({"cases":27,"failures":failures,"deferred_warning":true}))
	quit(0 if failures.is_empty() else 1)
