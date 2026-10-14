class_name HordeSound
extends Node

var enabled=true
var music: AudioStreamPlayer
var players: Array[AudioStreamPlayer]=[]
var clips: Dictionary={}
var track=""
var last_played: Dictionary={}

func _ready() -> void:
	music=AudioStreamPlayer.new()
	music.volume_db=-10
	add_child(music)
	for i in range(8):
		var player=AudioStreamPlayer.new()
		player.volume_db=-12
		add_child(player)
		players.append(player)
	for name in ["coin","jump","land","recruit","hit","smash","perk","guard","buy","challenge","finish"]:
		clips[name]=load("res://assets/audio/"+name+".ogg")
	for name in ["moon_menu","midnight_run"]:
		var stream=load("res://assets/audio/"+name+".ogg") as AudioStreamOggVorbis
		stream.loop=true
		clips[name]=stream

func set_enabled(value: bool) -> void:
	enabled=value
	music.stream_paused=not value
	if not value:
		for player in players: player.stop()

func set_music(name: String) -> void:
	if track==name: return
	track=name
	music.volume_db=-13 if name=="midnight_run" else -10
	music.stream=clips[name]
	music.play()
	music.stream_paused=not enabled

func play(name: String) -> void:
	if not enabled or not clips.has(name): return
	var time=Time.get_ticks_msec()
	if time-int(last_played.get(name,0))<55: return
	last_played[name]=time
	for player in players:
		if not player.playing:
			player.stream=clips[name]
			player.pitch_scale=1.0 if name in ["perk","finish","challenge"] else randf_range(.97,1.04)
			player.play()
			return
