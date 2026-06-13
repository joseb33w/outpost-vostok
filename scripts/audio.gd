class_name GameAudio
extends Node

const SOUNDS := ["shot_rifle", "shot_pistol", "shot_plasma", "reload", "hurt", "impact",
	"enemy_die", "boss_roar", "wave_start", "dodge", "click", "amb_wind"]

var _streams: Dictionary = {}
var _player: AudioStreamPlayer
var _amb: AudioStreamPlayer

func _ready() -> void:
	for s in SOUNDS:
		_streams[s] = load("res://audio/%s.wav" % s)
	_player = AudioStreamPlayer.new()
	_player.max_polyphony = 12
	_player.volume_db = -4.0
	add_child(_player)
	_amb = AudioStreamPlayer.new()
	var wind: AudioStreamWAV = _streams["amb_wind"]
	wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wind.loop_begin = 0
	wind.loop_end = wind.data.size() / 2
	_amb.stream = wind
	_amb.volume_db = -16.0
	add_child(_amb)

func play(sound: String, vol_db := 0.0) -> void:
	if not _streams.has(sound):
		return
	var pb := _player.get_stream_playback()
	if pb == null:
		_player.stream = AudioStreamPolyphonic.new()
		_player.play()
		pb = _player.get_stream_playback()
	var poly := pb as AudioStreamPlaybackPolyphonic
	if poly != null:
		poly.play_stream(_streams[sound], 0.0, vol_db, randf_range(0.94, 1.06))

func start_ambience() -> void:
	if not _amb.playing:
		_amb.play()
