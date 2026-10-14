class_name HordeSound
extends Node

var enabled=true
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var players: Array[AudioStreamPlayer]=[]
var clips: Dictionary={}
var track=""
var last_played: Dictionary={}
var last_voice=-5000

func _ready() -> void:
	music=AudioStreamPlayer.new();music.volume_db=-13;add_child(music)
	ambience=AudioStreamPlayer.new();ambience.volume_db=-27;add_child(ambience)
	for i in range(12):
		var player=AudioStreamPlayer.new();player.volume_db=-12;add_child(player);players.append(player)
	for name in ["coin","jump","land","recruit","hit","smash","perk","guard","buy","challenge","finish","voice_zombie","voice_zombie_alt","voice_skeleton","voice_masked","voice_fly","death_zombie","death_skeleton","death_masked","death_fly","city_scream","gunshot","explosion","tunnel"]:
		clips[name]=load("res://assets/audio/"+name+".ogg")
	for name in ["moon_menu","midnight_run","city_ambience"]:
		var stream=load("res://assets/audio/"+name+".ogg") as AudioStreamOggVorbis
		stream.loop=true;clips[name]=stream

func set_enabled(value: bool) -> void:
	enabled=value;music.stream_paused=not value;ambience.stream_paused=not value
	if not value:
		for player in players: player.stop()

func set_music(name: String) -> void:
	if track==name: return
	track=name;music.volume_db=-15 if name=="midnight_run" else -12
	music.stream=clips[name];music.play();music.stream_paused=not enabled

func set_area(area: int,running: bool) -> void:
	if area==1 and running:
		if not ambience.playing:
			ambience.stream=clips.city_ambience;ambience.play()
		ambience.stream_paused=not enabled
	else: ambience.stop()

func play_monster(kind: int,death: bool=false) -> void:
	if not death:
		var now=Time.get_ticks_msec()
		if now-last_voice<1300: return
		last_voice=now
	var names=["zombie","skeleton","masked","fly"]
	var name=("death_" if death else "voice_")+names[clampi(kind,0,3)]
	if kind==0 and not death and randf()<.5: name="voice_zombie_alt"
	play(name,-12 if death else -17)

func play(name: String,volume: float=-12) -> void:
	if not enabled or not clips.has(name): return
	var now=Time.get_ticks_msec()
	if now-int(last_played.get(name,-1000))<70: return
	last_played[name]=now
	for player in players:
		if not player.playing:
			player.stream=clips[name];player.volume_db=volume
			player.pitch_scale=1.0 if name in ["perk","finish","challenge","tunnel"] else randf_range(.96,1.04)
			player.play();return
