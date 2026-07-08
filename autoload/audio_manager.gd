extends Node
# Autoload: AudioManager
# Mirrors AudioEngine usage in C++ — music rotation, SFX, mute.

const MUSIC_TRACKS: Array = [
	"res://resources/audio/vg_bt_music.mp3",
	"res://resources/audio/diego_music.mp3",
	"res://resources/audio/POL-turtle-blues-short.mp3",
]
const MUSIC_VOLUME: float = 0.4
const SFX_BUTTON:    String = "res://resources/audio/button.mp3"
const SFX_JUMP:      String = "res://resources/audio/jump.mp3"
const SFX_SMASH:     String = "res://resources/audio/smash.mp3"
const SFX_SWOOSH:    String = "res://resources/audio/swoosh.mp3"
const SFX_LIGHTNING: String = "res://resources/audio/lightning.mp3"

var _music_index: int = 0
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	_music_player.finished.connect(_on_music_finished)

func play_music() -> void:
	if SaveManager.is_mute():
		return
	var path: String = MUSIC_TRACKS[_music_index]
	_music_index = (_music_index + 1) % MUSIC_TRACKS.size()
	var stream: AudioStream = load(path)
	if stream:
		_music_player.stream = stream
		_music_player.volume_db = linear_to_db(MUSIC_VOLUME)
		_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func play_sfx(path: String) -> void:
	if SaveManager.is_mute():
		return
	var stream: AudioStream = load(path)
	if stream:
		_sfx_player.stream = stream
		_sfx_player.play()

func set_mute(mute: bool) -> void:
	SaveManager.set_mute(mute)
	if mute:
		stop_music()
	else:
		play_music()

func _on_music_finished() -> void:
	play_music()
