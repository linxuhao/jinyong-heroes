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

## UI language: "zh" or "en". First launch auto-detects from the OS locale
## (on the web export OS.get_locale_language() maps from the browser
## language); a persisted choice overrides detection. HEADLESS runs are
## always "zh": the playtest/unit harness asserts the Chinese source strings
## byte-for-byte, so the harness must never depend on the box's locale or on
## a stray persisted settings.cfg.
var language: String = "zh"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	language = _detect_language()
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

## Set the UI language ("zh"/"en"; anything else is ignored), apply it live
## (TranslationServer relocale — auto-translated Controls re-render on the
## spot) and persist it.
func set_language(lang: String) -> void:
	if lang != "zh" and lang != "en":
		return
	language = lang
	_apply()
	_save()

## Restore the defaults (0.0 dB SFX / -10.0 dB music / windowed).
## Deliberately does NOT touch `language`: the harness baseline
## (debug_reset_settings) predates the language setting and playtest
## scenarios must keep their byte-identical Chinese surface.
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
	# A persisted choice overrides the auto-detect — but ONLY in an exported
	# build, which is the only place a real player can have made one.
	#
	# The guard used to ask `DisplayServer.get_name() != "headless"`, and the
	# play-test harness is never headless (it runs on Xvfb in render mode
	# whenever a scenario captures frames), so the harness read settings.cfg
	# like a player would. One scenario mis-counted its keystrokes, activated
	# the 语言 row instead of 返回, and persisted language=en into the shared
	# user dir — after which EVERY later run inherited English and the suite,
	# which asserts the Chinese source strings byte-for-byte, went red. Fixing
	# _detect_language() alone did not help: measured 2026-08-28, a frame
	# captured two hours after that fix was still English, because this line
	# was still handing the stale file's answer back.
	#
	# `template` is the right question. A player runs an EXPORTED build (web or
	# desktop) and OS.has_feature("template") is true there; the harness runs
	# the editor binary with --path and it is false. So a desktop player's
	# language choice still survives a restart — the reason this guard was left
	# alone the first time — while no harness run can be steered by a file some
	# other scenario wrote.
	if OS.has_feature("template"):
		var lang := str(cfg.get_value("general", "language", ""))
		if lang == "zh" or lang == "en":
			language = lang

## Applies the current mirrors: pushes the volumes into AudioManager (which
## guards the players) and — only when a real window exists — the window mode.
func _apply() -> void:
	AudioManager.set_sfx_volume_db(sfx_volume_db)
	AudioManager.set_music_volume_db(music_volume_db)
	# zh renders the source strings (fallback locale is zh_CN, no zh table —
	# lookups miss and the Chinese key itself is displayed); en hits I18n's
	# registered table.
	TranslationServer.set_locale("zh_CN" if language == "zh" else "en")
	if DisplayServer.get_name() == "headless":
		return
	get_window().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED

## Persists the three settings to settings.cfg (audio + display sections).
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_volume_db", sfx_volume_db)
	cfg.set_value("audio", "music_volume_db", music_volume_db)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("general", "language", language)
	cfg.save(SETTINGS_PATH)


## First-launch language: Chinese OS/browser locale -> zh, anything else ->
## en. Headless (playtest/unit harness) is always zh — the assertion surface
## is the Chinese source text.
func _detect_language() -> String:
	# Auto-detect ONLY on the web export. That is where the feature earns its
	# keep — OS.get_locale_language() maps from the browser language, so someone
	# opening the Pages build from outside China lands in English without being
	# asked. EVERY other run pins to "zh": desktop, and BOTH harness modes.
	#
	# This used to key on `DisplayServer.get_name() == "headless"`, and that
	# guard NEVER FIRED. The play-test harness runs Godot in RENDER mode on Xvfb
	# whenever a scenario asks for frame captures — which is the default path —
	# because --headless forces the dummy rendering driver and photographs an
	# empty viewport. Measured 2026-08-28: render_mode=render,
	# SettingsManager.language=en, and 10 scenarios asserting the Chinese source
	# strings byte-for-byte went red (PointsLabel read "Points left: 30", the map
	# event body read "Up/down to choose, Enter to decide").
	#
	# The guard picked the wrong fact: "am I headless" is not the same question
	# as "am I a real player". OS.has_feature("web") asks what the feature
	# actually cares about, and needs no cooperation from the harness to stay
	# true. A desktop player who picks English still gets it back on next launch
	# — that is _load()'s job and it is untouched.
	if not OS.has_feature("web"):
		return "zh"
	return "zh" if OS.get_locale_language().begins_with("zh") else "en"
