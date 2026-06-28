extends Node

const MENU_MUSIC := preload("res://Audio/music/menu_lobby.ogg")
const GAMEPLAY_MUSIC := preload("res://Audio/music/gameplay_loop.ogg")
const WORLD_AMBIENCE := preload("res://Audio/ambience/cave_ambience.ogg")

const SFX_STREAMS := {
	&"ui_confirm": preload("res://Audio/sfx/ui_confirm.ogg"),
	&"ui_back": preload("res://Audio/sfx/ui_back.ogg"),
	&"player_jump": preload("res://Audio/sfx/player_jump.ogg"),
	&"player_dash": preload("res://Audio/sfx/player_dash.ogg"),
	&"enemy_hit": preload("res://Audio/sfx/enemy_hit.ogg"),
	&"enemy_death": preload("res://Audio/sfx/enemy_death.ogg")
}

const SFX_POOL_SIZE := 8

var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _current_music: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = _make_player("MusicPlayer", -12.0)
	_ambience_player = _make_player("AmbiencePlayer", -18.0)
	_music_player.finished.connect(_restart_music)
	_ambience_player.finished.connect(_restart_ambience)

	for i in SFX_POOL_SIZE:
		var player = _make_player("SfxPlayer" + str(i + 1), -5.0)
		_sfx_players.append(player)

func play_menu_music() -> void:
	_play_music(MENU_MUSIC, &"menu")
	stop_ambience()

func play_gameplay_music() -> void:
	_play_music(GAMEPLAY_MUSIC, &"gameplay")

func stop_music() -> void:
	_current_music = &""
	_music_player.stop()

func play_world_ambience() -> void:
	if _ambience_player.stream == WORLD_AMBIENCE and _ambience_player.playing:
		return
	_ambience_player.stream = WORLD_AMBIENCE
	_ambience_player.play()

func stop_ambience() -> void:
	_ambience_player.stop()

func play_sfx(sound_name: StringName) -> void:
	var stream = SFX_STREAMS.get(sound_name)
	if stream == null:
		push_warning("AudioManager: unknown SFX '" + str(sound_name) + "'.")
		return

	var player = _next_available_sfx_player()
	player.stream = stream
	player.play()

func _play_music(stream: AudioStream, music_name: StringName) -> void:
	if _current_music == music_name and _music_player.playing:
		return
	_current_music = music_name
	_music_player.stream = stream
	_music_player.play()

func _make_player(node_name: String, volume_db: float) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.name = node_name
	player.bus = "Master"
	player.volume_db = volume_db
	add_child(player)
	return player

func _next_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player

	var player = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	return player

func _restart_music() -> void:
	if _music_player.stream != null and _current_music != &"":
		_music_player.play()

func _restart_ambience() -> void:
	if _ambience_player.stream != null:
		_ambience_player.play()
