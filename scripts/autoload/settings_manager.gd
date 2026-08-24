## SettingsManager (autoload)
##
## Single persistence point for small user preferences. Reads and writes
## user://settings.cfg via ConfigFile (INI-ish text). Owns the mirrored
## volume values and the fullscreen intent; applies them live through
## AudioManager's setters and the window mode API.
##
## Registered AFTER AudioManager in project.godot [autoload] (its _ready()
## runs after AudioManager built its two players) and BEFORE SceneManager
## (SceneManager must stay the last autoload entry). The registration line
## and the debug_reset_settings input action are owned by the
## project_godot_config task — "debug_reset_settings" is referenced here as
## a string contract only.
##
## Fullscreen is applied ONLY when not headless (DisplayServer.get_name() !=
## "headless") — a platform-API guard, NOT a behavior branch of the main
## scene. Volume is pure data and is safe to apply headless.
extends Node

const SETTINGS_PATH: String = "user://settings.cfg"
const VOL_MIN_DB: float = -40.0
const VOL_MAX_DB: float = 6.0
const DEFAULT_SFX_DB: float = 0.0
## Keep in sync with AudioManager.MUSIC_VOLUME_DB
## (scripts/autoload/audio_manager.gd line 32) — the default must equal the
## constant the music player is built with.
const DEFAULT_MUSIC_DB: float = -10.0

# ---------------------------------------------------------------------------
# Surface (playtest-assertable mirrors of the persisted settings)
# ---------------------------------------------------------------------------

var sfx_volume_db: float = DEFAULT_SFX_DB
var music_volume_db: float = DEFAULT_MUSIC_DB
var fullscreen: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load()
	_apply()

func _process(_delta: float) -> void:
	# Harness-only reset: gives playtest scenarios a deterministic baseline,
	# since settings.cfg persists across processes on the same user dir.
	if Input.is_action_just_pressed("debug_reset_settings"):
		reset_to_defaults()

# ---------------------------------------------------------------------------
# Public API — each setter applies AND persists
# ---------------------------------------------------------------------------

## Set the SFX volume (clamped to [VOL_MIN_DB, VOL_MAX_DB]), apply it live
## and persist it.
func set_sfx_volume_db(v: float) -> void:
	sfx_volume_db = clampf(v, VOL_MIN_DB, VOL_MAX_DB)
	_apply()
	_save()

## Set the music volume (clamped to [VOL_MIN_DB, VOL_MAX_DB]), apply it live
## and persist it.
func set_music_volume_db(v: float) -> void:
	music_volume_db = clampf(v, VOL_MIN_DB, VOL_MAX_DB)
	_apply()
	_save()

## Set the fullscreen intent, apply it (headless-guarded) and persist it.
func set_fullscreen(b: bool) -> void:
	fullscreen = b
	_apply()
	_save()

## Restore the defaults (0.0 dB SFX / -10.0 dB music / windowed).
func reset_to_defaults() -> void:
	set_sfx_volume_db(DEFAULT_SFX_DB)
	set_music_volume_db(DEFAULT_MUSIC_DB)
	set_fullscreen(false)

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Reads the three settings from settings.cfg; absent file or missing keys
## fall back to the defaults. Volumes are clamped on read too, so a hand
## edited file cannot push them out of range.
func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	sfx_volume_db = clampf(float(cfg.get_value("audio", "sfx_volume_db", DEFAULT_SFX_DB)), VOL_MIN_DB, VOL_MAX_DB)
	music_volume_db = clampf(float(cfg.get_value("audio", "music_volume_db", DEFAULT_MUSIC_DB)), VOL_MIN_DB, VOL_MAX_DB)
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))

## Applies the current mirrors: pushes the volumes into AudioManager (which
## guards the players) and — only when a real window exists — the window mode.
func _apply() -> void:
	AudioManager.set_sfx_volume_db(sfx_volume_db)
	AudioManager.set_music_volume_db(music_volume_db)
	if DisplayServer.get_name() == "headless":
		return
	get_window().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED

## Persists the three settings to settings.cfg (audio + display sections).
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_volume_db", sfx_volume_db)
	cfg.set_value("audio", "music_volume_db", music_volume_db)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)
