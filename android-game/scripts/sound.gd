class_name StreetSound
extends Node

var clips: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var engine: AudioStreamPlayer
var enabled = true

func _ready() -> void:
	for name_value in ["shot","pickup","reload","mission","step","engine"]:
		clips[name_value] = synth(name_value)
	for i in range(7):
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -15
		add_child(voice)
		voices.append(voice)
	engine = AudioStreamPlayer.new()
	engine.stream = clips.engine
	engine.volume_db = -25
	add_child(engine)

func synth(kind: String) -> AudioStreamWAV:
	var rate = 22050
	var seconds = 1.0 if kind=="engine" else (0.65 if kind=="mission" else 0.18)
	var data = PackedByteArray()
	data.resize(int(rate*seconds)*2)
	var random = RandomNumberGenerator.new()
	random.seed = 4331
	for i in range(data.size()/2):
		var t = float(i)/rate
		var env = pow(1.0-t/seconds,2)
		var sample = 0.0
		match kind:
			"shot": sample = (random.randf_range(-1,1)*0.7+sin(t*TAU*85)*0.3)*pow(env,5)
			"pickup": sample = sin(t*TAU*(660 if t<0.09 else 880))*env*0.45
			"reload": sample = random.randf_range(-1,1)*env*(0.5 if t<0.04 or t>0.12 else 0.0)
			"mission": sample = (sin(t*TAU*440)+sin(t*TAU*554.37)+sin(t*TAU*659.25))*env*0.13
			"step": sample = random.randf_range(-1,1)*pow(env,8)*0.25
			"engine": sample = (sin(t*TAU*50)+sin(t*TAU*100)*0.35+sin(t*TAU*150)*0.20)*0.30
		data.encode_s16(i*2,int(clampf(sample,-1,1)*32760))
	var clip = AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = rate
	clip.data = data
	if kind=="engine":
		clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip.loop_end = data.size()/2
	return clip

func play(key: String,pitch: float = 1.0) -> void:
	if not enabled or not clips.has(key): return
	for voice in voices:
		if not voice.playing:
			voice.stream = clips[key]
			voice.pitch_scale = pitch
			voice.play()
			return

func update_motor(speed: float,active: bool) -> void:
	if active and enabled:
		if not engine.playing: engine.play()
		engine.pitch_scale = 0.85+absf(speed)*0.065
		engine.volume_db = -25+minf(absf(speed)*0.10,4)
	else:
		engine.stop()
