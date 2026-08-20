## AudioManager (autoload)
##
## The single owner of all audio playback. Preloads the six generated audio
## streams (5 SFX + 1 music bed) and exposes a no-arg, always-safe public API
## callable from any autoload or character script. Builds its two
## AudioStreamPlayer children at runtime (an autoload has no scene).
##
## Runs AFTER GameManager / CombatManager (5th [autoload] entry), so its
## _ready() can wire itself to their signals.
extends Node

# ---------------------------------------------------------------------------
# Constants — preloaded streams (compile-time dependencies)
# ---------------------------------------------------------------------------

const HIT: AudioStream = preload("res://assets/audio/hit.wav")
const HURT: AudioStream = preload("res://assets/audio/hurt.wav")
const MOVE: AudioStream = preload("res://assets/audio/move.wav")
const SELECT: AudioStream = preload("res://assets/audio/select.wav")
const VICTORY: AudioStream = preload("res://assets/audio/victory.wav")
const MUSIC: AudioStream = preload("res://assets/audio/music.wav")

## Minimum interval between hurt sounds (guards DoT-tick spam), in ms.
const HURT_THROTTLE_MS: int = 150

## Music bed volume, ~10 dB under the SFX player.
const MUSIC_VOLUME_DB: float = -10.0

## Max simultaneous voices on the SFX player — rapid hits/moves must not cut
## each other off.
const SFX_MAX_POLYPHONY: int = 8

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Shared SFX player (all short transients).
var _sfx_player: AudioStreamPlayer = null

## Dedicated music bed player.
var _music_player: AudioStreamPlayer = null

## Timestamp (ms) of the last played hurt sound, for throttling.
var _last_hurt_msec: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_players()
	_connect_signals()

# ---------------------------------------------------------------------------
# Public API (no-arg, always-safe)
# ---------------------------------------------------------------------------

## Play the hit SFX.
func play_hit() -> void:
	_play_sfx(HIT)

## Play the hurt SFX, throttled to >= HURT_THROTTLE_MS between plays.
func play_hurt() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_hurt_msec < HURT_THROTTLE_MS:
		return
	_last_hurt_msec = now
	_play_sfx(HURT)

## Play the move SFX.
func play_move() -> void:
	_play_sfx(MOVE)

## Play the select SFX.
func play_select() -> void:
	_play_sfx(SELECT)

## Stop the music bed and play the victory jingle once.
func play_victory() -> void:
	stop_music()
	_play_sfx(VICTORY)

## Start the music bed if it is not already playing.
func play_music() -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return
	if _music_player.playing:
		return
	_music_player.play()

## Stop the music bed. Does NOT emit `finished`, so the restart-on-finished
## handler cannot fight a deliberate stop.
func stop_music() -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		return
	_music_player.stop()

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Builds the two AudioStreamPlayer children (the autoload has no scene).
func _build_players() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.max_polyphony = SFX_MAX_POLYPHONY
	_sfx_player.volume_db = 0.0
	add_child(_sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.stream = MUSIC
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)

## Wires the GameManager / CombatManager signals plus the music replay.
func _connect_signals() -> void:
	GameManager.battle_started.connect(play_music)
	GameManager.game_won.connect(play_victory)
	GameManager.game_lost.connect(stop_music)
	CombatManager.damage_dealt.connect(_on_damage_dealt)
	_music_player.finished.connect(_on_music_finished)

## Guarded playback helper: plays a stream on the shared SFX player.
func _play_sfx(stream: AudioStream) -> void:
	if _sfx_player == null or not is_instance_valid(_sfx_player):
		return
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()

## Restarts the music bed when it reaches its natural end. The generated WAV
## has no authored loop point, so we restart instead of looping (a small seam
## gap is explicitly acceptable).
func _on_music_finished() -> void:
	if _music_player != null and is_instance_valid(_music_player):
		_music_player.play()

## Plays the hurt SFX when the damage target is the player. DoT ticks also
## emit damage_dealt; the throttle inside play_hurt() guards the spam.
func _on_damage_dealt(target: Node, _amount: int, _is_lethal: bool) -> void:
	if target == null:
		return
	var player: Node = GameManager.get_player()
	if target == player or target.name == "Player":
		play_hurt()
