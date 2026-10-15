class_name HordeProgress
extends RefCounted

const RITUAL_TARGET=100

static func level_target(level: int) -> int:
	var n=maxi(0,level-1)
	return 20+12*n+4*n*n

static func board(level: int,progress: int,added: int) -> Dictionary:
	var current=clampi(level,1,500);var souls=maxi(0,progress)+maxi(0,added)
	while current<500 and souls>=level_target(current):
		souls-=level_target(current);current+=1
	return {"level":current,"progress":mini(souls,level_target(current)-1),"target":level_target(current)}

static func settle(data: Dictionary,souls: int,rng: RandomNumberGenerator) -> Dictionary:
	var report={"old_level":int(data.player_level),"old_progress":int(data.level_souls),"souls":maxi(0,souls),"coins":0,"rewards":[],"levels":0}
	data.best_souls=maxi(int(data.best_souls),maxi(0,souls))
	data.total_souls=mini(9999999,int(data.total_souls)+maxi(0,souls))
	data.level_souls+=maxi(0,souls)
	while int(data.player_level)<500 and int(data.level_souls)>=level_target(int(data.player_level)):
		data.level_souls-=level_target(int(data.player_level))
		var coins=rng.randi_range(140,260)+mini(30,int(data.player_level))*12
		data.wallet=mini(9999999,int(data.wallet)+coins)
		report.coins+=coins;report.levels+=1;report.rewards.append(coins)
		data.player_level+=1
	data.level_souls=mini(int(data.level_souls),level_target(int(data.player_level))-1)
	data.active_souls=0;data.ritual_ready=true
	return report

static func queue_mission(data: Dictionary,mission: Dictionary) -> void:
	for item in data.ritual_pending:
		if item.key==mission.key: return
	data.ritual_pending.append({"key":mission.key,"title":mission.title,"points":int(mission.ritual)})

static func ritual(data: Dictionary,rng: RandomNumberGenerator) -> Dictionary:
	var result={"old_progress":int(data.ritual_progress),"points":0,"coins":0,"bonuses":0}
	if not bool(data.ritual_ready): return result
	for item in data.ritual_pending: result.points+=int(item.points)
	data.ritual_progress+=int(result.points)
	while int(data.ritual_progress)>=RITUAL_TARGET:
		data.ritual_progress-=RITUAL_TARGET
		var coins=rng.randi_range(250,500)+mini(20,int(data.player_level))*20
		data.wallet=mini(9999999,int(data.wallet)+coins)
		result.coins+=coins;result.bonuses+=1
	data.ritual_pending.clear();data.ritual_ready=false
	return result
