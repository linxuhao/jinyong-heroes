"""Static guard: every Chinese string a player can SEE has an English entry.

The game ships an EN table (scripts/autoload/i18n.gd, the ``EN`` Dictionary
constant, registered with TranslationServer by the I18n autoload in
_enter_tree). Coverage is enforced by nothing at runtime: a lookup that misses
simply renders the Chinese source, so an untranslated label looks EXACTLY like a
translated one to every automated check this project has. The only signal is an
English-speaking player seeing Chinese -- and this game is being built in public
for an audience that does not read it.

Measured when this file was written (2026-08-28): all 177 ``tr("<zh>")`` call
sites were covered and exactly ONE scene label was not -- ``退回``, the UndoButton
added the same day. One gap opening within hours of the table being written is
the argument for the guard: the table and the UI drift apart silently, by
default, and nothing else in the repo can see it.

Deliberately stdlib-only and Godot-free, like the other static guards under
tests/, so it runs in the ordinary pytest pass with no Godot binary.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "scripts" / "autoload" / "i18n.gd"

# The EN table is a Dictionary constant of "<zh>": "<en>" pairs and
# add_message() is called in a LOOP over it, so scanning for add_message("...")
# literals finds NOTHING. An earlier version of this check did exactly that and
# reported 36 false gaps -- the extraction, not the game, was broken. Hence the
# key-count sanity assert in _en_keys().
_DICT_KEY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*:', re.M)
_SCENE_TEXT = re.compile(r'^\s*text\s*=\s*"((?:[^"\\]|\\.)*)"', re.M)
_TR_CALL = re.compile(r'\btr\(\s*"((?:[^"\\]|\\.)*)"')
_ASSIGN_TEXT = re.compile(r'\.text\s*=\s*"((?:[^"\\]|\\.)*)"')


def _has_cjk(s):
    return any("一" <= c <= "鿿" for c in s)


def _en_keys():
    keys = set(_DICT_KEY.findall(I18N.read_text(encoding="utf-8")))
    # Without this, a broken extraction would make every assertion below pass by
    # having nothing to compare against -- the exact failure mode that produced
    # the 36 phantom gaps, only inverted and silent.
    assert len(keys) > 100, "EN table extraction found only %d keys" % len(keys)
    return keys


def _gaps(paths, pattern, skip_i18n=False):
    keys = _en_keys()
    out = []
    for p in paths:
        if skip_i18n and p.name == "i18n.gd":
            continue
        for k in pattern.findall(p.read_text(encoding="utf-8")):
            if _has_cjk(k) and k not in keys:
                out.append("%s: %s" % (p.relative_to(ROOT), k))
    return out


def test_scene_labels_have_english():
    """A CJK ``text =`` in a .tscn rides Control auto-translate, which keys on
    the literal itself; no entry means the label stays Chinese in EN mode."""
    gaps = _gaps(sorted((ROOT / "scenes").rglob("*.tscn")), _SCENE_TEXT)
    assert not gaps, "scene labels with no EN entry:\n  " + "\n  ".join(gaps)


def test_tr_call_sites_have_english():
    """``tr("<zh>")`` with no table entry returns its argument unchanged."""
    gaps = _gaps(sorted((ROOT / "scripts").rglob("*.gd")), _TR_CALL, skip_i18n=True)
    assert not gaps, 'tr("<zh>") with no EN entry:\n  ' + "\n  ".join(gaps)


def test_direct_text_assignments_have_english():
    """``label.text = "<zh>"`` skips tr(); auto-translate re-runs on assignment
    and is keyed the same way, so the same entry is required."""
    gaps = _gaps(sorted((ROOT / "scripts").rglob("*.gd")), _ASSIGN_TEXT, skip_i18n=True)
    assert not gaps, 'direct .text = "<zh>" with no EN entry:\n  ' + "\n  ".join(gaps)
