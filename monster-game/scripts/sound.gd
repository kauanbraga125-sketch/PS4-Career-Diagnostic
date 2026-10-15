class_name HordeSound
extends Node

var enabled=true
var music: AudioStreamPlayer
var music_players: Array[AudioStreamPlayer]=[]
var music_weights=[1.0,0.0]
var music_targets=[1.0,0.0]
var music_index=0
var ambience: AudioStreamPlayer
var players: Array[AudioStreamPlayer]=[]
var clips: Dictionary={}
var track=""
var last_played: Dictionary={}
var last_voice=-5000
var rotor: AudioStreamPlayer
var engine: AudioStreamPlayer
var fire: AudioStreamPlayer
var wings: AudioStreamPlayer
var cauldron: AudioStreamPlayer
var footsteps: AudioStreamPlayer
var heavy_steps: AudioStreamPlayer
var jar_loop: AudioStreamPlayer
var atmosphere: Array[AudioStreamPlayer]=[]
var atmosphere_key=""
var atmosphere_index=0
var atmosphere_weights=[0.0,0.0]
var atmosphere_targets=[0.0,0.0]
var variants: Dictionary={}
var variant_next: Dictionary={}
var group_last: Dictionary={}
var loop_choices: Dictionary={}
var duck_left=0.0
var duck_db=0.0
var mix_levels={"music":.75,"effects":.85,"voices":1.0}

func _ready() -> void:
	if AudioServer.get_bus_effect_count(0)==0:
		var limiter=AudioEffectHardLimiter.new();limiter.ceiling_db=-.8;limiter.release=.08
		AudioServer.add_bus_effect(0,limiter)
	for bus in ["HordeMusic","HordeEffects","HordeVoices"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	for i in range(2):
		var player=AudioStreamPlayer.new();player.bus="HordeMusic";add_child(player);music_players.append(player)
	music=music_players[0]
	ambience=loop_player();rotor=loop_player();engine=loop_player();fire=loop_player();wings=loop_player();cauldron=loop_player()
	for i in range(18):
		var player=AudioStreamPlayer.new();add_child(player);players.append(player)
	for name in ["coin","jump","land","recruit","hit","smash","perk","guard","buy","challenge","finish","voice_zombie","voice_zombie_alt","voice_skeleton","voice_masked","voice_fly","death_zombie","death_skeleton","death_masked","death_fly","city_scream","gunshot","explosion","tunnel","soul_capture","level_up","ritual_fill","metal_push","glass_break","civil_male","civil_worker","civil_female","police_stop","army_command","transform_fly","transform_mask","revive","car_crash","car_horn","car_approach_1","car_approach_2"]:
		clips[name]=load("res://assets/audio/"+name+".ogg")
	clips.voice_masked=load("res://assets/audio/voice_masked_v4.ogg")
	for i in range(1,5):
		for prefix in ["civil_new_","zombie_chuckle_"]:clips[prefix+str(i)]=load("res://assets/audio/"+prefix+str(i)+".ogg")
	for kind in MonsterCatalog.VEHICLES:clips["smash_"+kind]=load("res://assets/audio/smash_"+kind+".ogg")
	for name in ["city_ambience","helicopter_loop","plane_loop","engine_loop","fire_loop","fly_wings_loop","cauldron_loop","music_menu_v6","music_early_v6","music_late_v6"]:
		var stream=load("res://assets/audio/"+name+".ogg") as AudioStreamOggVorbis
		stream.loop=true;clips[name]=stream
	clips.moon_menu=clips.music_menu_v6;clips.midnight_run=clips.music_early_v6;clips.midnight_late=clips.music_late_v6
	footsteps=loop_player();heavy_steps=loop_player();jar_loop=loop_player()
	for i in range(2):atmosphere.append(loop_player())
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/v7/manifest.json"))
	for file in manifest.files:
		var key=str(file.event)
		if not variants.has(key):variants[key]=[]
		var name=str(file.output).trim_suffix(".ogg")
		var stream=load("res://assets/audio/v7/"+str(file.output)) as AudioStreamOggVorbis
		stream.loop=bool(file.loop);clips[name]=stream;variants[key].append(name)
	set_mix(mix_levels)

func loop_player() -> AudioStreamPlayer:
	var player=AudioStreamPlayer.new();player.bus="HordeEffects";add_child(player);return player

func set_mix(value: Dictionary) -> void:
	for channel in ["music","effects","voices"]:
		mix_levels[channel]=clampf(float(value.get(channel,mix_levels[channel])),0,1)
		var bus="HordeMusic" if channel=="music" else ("HordeVoices" if channel=="voices" else "HordeEffects")
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),linear_to_db(maxf(.0001,mix_levels[channel])))

func _process(dt: float) -> void:
	duck_left=maxf(0,duck_left-dt)
	for i in range(2):
		atmosphere_weights[i]=move_toward(atmosphere_weights[i],atmosphere_targets[i],dt/1.1)
		atmosphere[i].volume_db=-13+linear_to_db(maxf(.0001,atmosphere_weights[i]))
		if atmosphere_weights[i]<=.001 and atmosphere_targets[i]==0:atmosphere[i].stop()
	var voice_active=false
	for p in players:
		if p.playing and p.bus=="HordeVoices" and mix_levels.voices>.001:voice_active=true;break
	duck_db=move_toward(duck_db,-8.0 if voice_active or duck_left>0 else 0.0,dt*(65 if voice_active or duck_left>0 else 11))
	if music.playing and music.stream.get_length()-music.get_playback_position()<1.1 and music_targets[music_index]==1:
		var same=track;track="";set_music(same)
	for i in range(2):
		music_weights[i]=move_toward(music_weights[i],music_targets[i],dt/.95)
		music_players[i].volume_db=-6+duck_db+linear_to_db(maxf(.0001,music_weights[i]))
		if music_weights[i]<=.001 and music_targets[i]==0:music_players[i].stop()

func set_enabled(value: bool) -> void:
	enabled=value
	for player in music_players+atmosphere+[ambience,rotor,engine,fire,wings,cauldron,footsteps,heavy_steps,jar_loop]:player.stream_paused=not value
	if not value:
		for player in players:player.stop()

func set_music(name: String) -> void:
	if track==name:return
	track=name
	music_targets[music_index]=0
	music_index=1-music_index;music=music_players[music_index]
	music.stream=clips[name];music.volume_db=-80;music.play();music.stream_paused=not enabled
	music_weights[music_index]=0;music_targets[music_index]=1

func set_area(area: int,running: bool) -> void:
	set_atmosphere("AMB_00" if area==1 and running else "")

func set_menu(active: bool) -> void:
	set_loop(cauldron,"cauldron_loop",active,-19)

func play_monster(kind: int,death: bool=false) -> void:
	if not death:
		var now=Time.get_ticks_msec()
		if now-last_voice<1300:return
		last_voice=now
	var names=["zombie","skeleton","masked","fly"]
	var name=("death_" if death else "voice_")+names[clampi(kind,0,3)]
	if kind==0 and not death:name="zombie_chuckle_"+str(randi_range(1,4)) if randf()<.7 else "voice_zombie_alt"
	play(name,-13 if death else -17)

func voice_clip(name: String) -> bool:
	return name.begins_with("voice_") or name.begins_with("death_") or name.begins_with("civil_") or name.begins_with("zombie_chuckle_") or name in ["police_stop","army_command","city_scream"]

func play(name: String,volume: float=-12) -> void:
	if not enabled:return
	var groups={"jump":"MOV_02","land":"MOV_03","heavy_land":"MOV_05","ui_confirm":"UI_01","ui_back":"UI_02","buy":"UI_03","ui_denied":"UI_04","coin":"REC_01","jar_full":"RIT_02","finish":"DER_01","recruit":"MON_01","member_lost":"MON_02","pit_fall":"MON_03","hit":"COL_01","perk":"POW_01","soul_capture":"REC_02","power_end":"POW_02"}
	if groups.has(name):
		play_group(groups[name],volume);return
	if name in ["civil_male","civil_worker","civil_female"]:name="civil_new_"+str(randi_range(1,4))
	if not clips.has(name):return
	var now=Time.get_ticks_msec()
	if now-int(last_played.get(name,-1000))<(1400 if voice_clip(name) and name not in ["death_zombie","voice_fly"] else 140 if name=="metal_push" else 90):return
	last_played[name]=now
	var voice=voice_clip(name)
	if mix_levels.effects>.001 and name in ["car_crash","explosion","transform_fly","transform_mask","smash_car"]:duck_left=maxf(duck_left,.65)
	var chosen: AudioStreamPlayer
	for player in players:
		if not player.playing:chosen=player;break
	if chosen==null and voice:
		for player in players:
			if player.bus!="HordeVoices":chosen=player;break
	if chosen==null:return
	chosen.bus="HordeVoices" if voice else "HordeEffects"
	chosen.stream=clips[name]
	chosen.volume_db=clampf((-3 if voice else -7)+(volume+17 if voice else volume+12),-29,0)
	chosen.pitch_scale=1.0 if name in ["perk","finish","challenge","tunnel","transform_fly","transform_mask","car_crash"] else randf_range(.985,1.025)
	chosen.play()

func update_course(run: HordeRun,running: bool,burning: bool=false) -> void:
	if not running:
		for p in [rotor,engine,fire,wings,footsteps,heavy_steps]:p.stop()
		set_atmosphere("")
		return
	set_music("midnight_late" if run.tunnel_number()>=6 else "midnight_run")
	var heli_distance=2000.0;var engine_distance=2000.0;var aircraft=false;var motorcycle=false
	for entity in run.entities:
		if entity.taken:continue
		if entity.kind=="helicopter":heli_distance=minf(heli_distance,absf(entity.x-HordeRun.ANCHOR))
		elif MonsterCatalog.VEHICLES.has(entity.kind) and absf(entity.x-HordeRun.ANCHOR)<engine_distance:
			engine_distance=absf(entity.x-HordeRun.ANCHOR);aircraft=entity.kind=="plane";motorcycle=entity.kind=="moto"
	set_loop(rotor,"helicopter_loop",heli_distance<1050,-24-clampf(heli_distance/1050,0,1)*10)
	set_loop(engine,loop_variant("VEI_01") if motorcycle else ("plane_loop" if aircraft else "engine_loop"),engine_distance<1050,-25-clampf(engine_distance/1050,0,1)*10)
	set_loop(fire,"fire_loop",burning,-27)
	set_loop(wings,"fly_wings_loop",run.perk_kind==3 and run.perk_left>0,-19)
	var grounded=0
	for m in run.members:
		if not m.falling and m.y>=HordeRun.FLOOR-.1 and m.vy==0 and m.push_left<=0:grounded+=1
	var on_ground=grounded>0 and run.transform_left<=0 and run.perk_kind!=3
	set_loop(footsteps,loop_variant("MOV_01"),on_ground and run.perk_kind!=2,-13)
	set_loop(heavy_steps,loop_variant("MOV_04"),on_ground and run.perk_kind==2,-14)
	set_atmosphere("AMB_04" if run.inside_tunnel() else ("AMB_00" if run.area()==1 else ""))

func set_loop(player: AudioStreamPlayer,name: String,active: bool,volume: float) -> void:
	if not active:player.stop();return
	if not player.playing or player.stream!=clips[name]:player.stream=clips[name];player.play()
	player.volume_db=volume;player.stream_paused=not enabled

func choose_variant(group: String) -> String:
	if not variants.has(group):return ""
	var options: Array=variants[group]
	var index=int(variant_next.get(group,randi_range(0,options.size()-1)))%options.size()
	variant_next[group]=(index+1)%options.size()
	return str(options[index])

func loop_variant(group: String) -> String:
	if not loop_choices.has(group):loop_choices[group]=choose_variant(group)
	return str(loop_choices[group])

func play_group(group: String,volume: float=-12,voice: bool=false) -> void:
	if not enabled or not variants.has(group):return
	var now=Time.get_ticks_msec()
	var interval=180 if group in ["MOV_03","MOV_05","MON_02","MON_03"] else (90 if group=="REC_01" else 70)
	if now-int(group_last.get(group,-10000))<interval:return
	group_last[group]=now
	var key=choose_variant(group)
	for p in players:
		if p.playing:continue
		p.stream=clips[key];p.bus="HordeVoices" if voice else "HordeEffects"
		p.volume_db=clampf(volume+6,-26,-2)
		p.pitch_scale=randf_range(.98,1.025) if group in ["REC_01","MOV_02","MOV_03"] else 1.0
		p.play();return

func celebrate() -> void:
	# Complementary guitar plus exactly one crowd voice; lower crowd level prevents masking.
	play_group("VIT_01",-11);play_group("VIT_02",-17,true);duck_left=.9

func set_jar(active: bool) -> void:
	set_loop(jar_loop,loop_variant("RIT_01"),active,-9)

func set_atmosphere(group: String) -> void:
	if group==atmosphere_key:return
	atmosphere_key=group
	atmosphere_targets[atmosphere_index]=0
	if group.is_empty():return
	atmosphere_index=1-atmosphere_index
	var p=atmosphere[atmosphere_index]
	p.stream=clips[choose_variant(group)];p.volume_db=-70;p.play();p.stream_paused=not enabled
	atmosphere_weights[atmosphere_index]=0;atmosphere_targets[atmosphere_index]=1
