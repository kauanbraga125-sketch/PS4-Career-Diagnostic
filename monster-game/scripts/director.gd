class_name HordeDirector
extends RefCounted

static func profile(world_px: float,count: int,pressure: float,recovery: float,stage: int=0) -> Dictionary:
	var metres=world_px/30.0
	var base=minf(710,305+world_px/230.0+stage*13)
	var target_pressure=clampf(float(count-5)/16.0,0,1)
	if stage>=5 and count>=10:target_pressure=minf(1,target_pressure+.25)
	if recovery>0 or count<=3:target_pressure=0
	var difficulty=clampf(stage*.12+metres/6500.0+pressure*.4,0,1)
	var recruit_chance=clampf(.36-pressure*.18-difficulty*.12,.14,.45)
	var cluster=mini(5,1+int(stage/2))
	var gap_chain=mini(4,1+int(stage/3))
	var speed=base+pressure*70
	if recovery>0 or count<=3:
		recruit_chance=.53 if recovery>0 else .44;cluster=mini(cluster,2);difficulty*=.72
		if recovery>0:gap_chain=mini(gap_chain,2)
	return {"stage":stage,"pressure_target":target_pressure,"difficulty":difficulty,"recruit_chance":recruit_chance,
		"gap":clampf(150+stage*24+pressure*50,150,410),"extra_hazard":.15+difficulty*.75,
		"speed":speed,"bullet_period":maxf(.9,2.0-difficulty),"cluster":cluster,"gap_chain":gap_chain,
		"spacing":maxf(520,speed*1.30),"pattern_pause":maxf(380,speed*(1.65-difficulty*.9)),
		"max_gap_interval":2700 if stage<2 else (2200 if stage<5 else 1800),"double_chance":.12+difficulty*.25}
