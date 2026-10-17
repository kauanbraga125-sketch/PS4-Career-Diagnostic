extends SceneTree
func _initialize() -> void:
	for stage in [3,8]:
		var r=HordeRun.new();r.start({},88801);r.entities.clear();r.tunnels.clear()
		r.entered_tunnels=stage;r.completed_tunnels=stage;r.speed=HordeDirector.stage_speed(stage);r.cruise_speed=r.speed;r.last_effective_speed=r.speed
		r.schedule_tunnel(stage+1,HordeTuning.tunnel_interval(r.speed))
		while r.members.size()<36:r.add_member(0,false)
		var count=0;var seen:Dictionary={}
		for frame in range(120*30):
			r.dead=false;r.hit_grace=1000
			while r.members.size()>36:r.members.pop_back()
			for i in range(r.members.size()):
				var m=r.members[i];m.x=r.slot_x(i);m.y=r.ground_y(m.x);m.vy=0;m.falling=false;m.jump_queue.clear()
			r.advance(1.0/30,false)
			for e in r.entities:
				if e.kind=="coin" and not seen.has(e.id):seen[e.id]=true;count+=1
			r.events.clear()
		print("COIN_DENSITY "+JSON.stringify({"stage":stage,"world":r.world_px,"coins_spawned":count,"per_1000px":count/r.world_px*1000}))
	quit()
