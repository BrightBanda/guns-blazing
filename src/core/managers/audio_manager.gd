extends Node

var music_player: AudioStreamPlayer

const SFX_POOL_SIZE: int = 12
var sfx_players: Array[AudioStreamPlayer] = []
var next_sfx_index: int = 0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

func play_sfx(stream: AudioStream, volume_db: float = 0.5, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = sfx_players[next_sfx_index]
	next_sfx_index = (next_sfx_index + 1)%SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func play_music(stream: AudioStream, volume_db: float = 0.3) -> void:
	if music_player.stream == stream && music_player.playing:
		return
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()

func stop_music() -> void:
	music_player.stop()
