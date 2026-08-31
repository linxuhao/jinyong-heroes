# Portrait Alpha-Bbox Probe Notes — per-PNG ink footing (M2, wuxia-shrimp-portraits)

**Task:** `portrait_alpha_bbox_probe` — measure the **true alpha bounding box** of each
of the six `assets/characters/*.png` (96×128 RGBA, colortype 6, non-interlaced) so the
texture-rect pin's blind spot — transparent bottom padding / off-center ink — is
independently checked, independent of the game's texture-rect-derived
`portrait_ink_rect` / `ink_world_dx/dy`.

**Read-only inputs.** The six PNGs are read for pixels, never rewritten. `playtest/`,
`scripts/`, and the four guard tests (`test_shrimp_roster.py`,
`test_playtest_contract_smoke.py`, `test_facility_copy_location.py`,
`test_i18n_coverage.py`) are untouched. The optional future bbox nail (a committed,
pinned bbox test) is **not** landed — that is an owner decision only (design
`30_presentation.md` texture-rect blind-spot record, optional nail proposal).

**Durable M2 record** consumed by `delivery_notes_and_handoff_archive`.

---

## ⚠️ Run status: probe execution BLOCKED — no execution capability in this step

The probe **could not be executed in this step**, and no measured alpha-bbox value is
claimed below.

Reason: the implementer toolset for this step provides **no execution path** —
no shell, no local Python, no pytest runner, and no `godot-builder` sidecar `/script`
invocation. The only execution-capable tool, `godot_playtest_scenario`, runs Godot
**play-test scenarios against live scene nodes** and evaluates only surface-whitelisted
observables; it cannot run an arbitrary stdlib Python PNG decoder, and no
alpha-bbox observable is (or may be) published on the play-test surface. `test_write`
only stores scratch content — it does not execute the `.py` it stores (verified by a
write+read-back smoke in this step).

This is the exact situation the project's honesty discipline covers (see
`final/portrait_probe_notes.md`, which recorded **PENDING** rather than fabricating when
the builder was unreachable, and the round brief: "no fabricated descriptions, ever",
"reds reported with root cause, never loosened"). Fabricating a `bottom_gap` / bbox
table here would poison the round's core deliverable — proving the new art's footing
with **observed** values — so no invented number is recorded.

**Consequence:** the measured-value table below is **PENDING, not measured**. The full,
runnable probe is embedded in §4; the first task/step that can execute it
(`python3 -m pytest tests/test_tmp_alpha_bbox_probe.py` — the pytest runner at a
downstream gate, or a sidecar-capable implementer) must run it and fill the measured
cells from the printed `ALPHA_BBOX_RESULTS` block. `delivery_notes_and_handoff_archive`
must not treat the PENDING cells as measured evidence; it should mark the M2 footing
sub-item as measured-only once the probe's `observed` values land.

The transient probe file `tests/test_tmp_alpha_bbox_probe.py` was **written to this
step's scratch only and is NOT in the committed tree** (verified: it was never created
in the repo; the committed tree has no `tests/test_tmp_alpha_bbox_probe.py`). It must
**not** be re-created/committed by a later round — a committed pinned bbox test is the
optional future nail (a), owner-decision-only (see §5).

---

## Metric definitions (the contract this probe measures)

For each PNG, at two thresholds — `t=0` (raw, `alpha > 0`) and `t=8` (`alpha >= 8`,
antialiasing-fringe guard) — over the 96×128 alpha channel (alpha = 4th RGBA byte):

- `bbox = (left, top, right, bottom)` — **inclusive** pixel coords of the ink set.
  `None` if no ink pixel at that threshold (all-transparent decode) — reported
  explicitly, never folded into a pass.
- `bottom_gap = 127 - bottom` — `0` ⇒ drawn ink touches the bottom row `y=127` ⇒
  the constant foot-anchor offset `(0, -tex.y/2)` places the feet on the tile
  (the post-process bottom-align guarantee holds at pixel level).
- `h_center_offset = (left + right) / 2 - 47.5` — `0` ⇒ ink horizontally centred
  (the post-process horizontal-centre guarantee holds; 96-wide image centre is x=47.5).
- `opaque_count` = number of ink pixels at that threshold.
- decode sanity (reviewer suggestion 1): `decode_ok = 96x128 RGBA`, total pixel
  count == `96*128` (asserted inside the decoder), and per-row opaque counts reported
  so the durable record keeps the reconstruction-validity evidence, not just the
  final metrics.

Decoder contract (pure stdlib `zlib` + `struct`, in §4): **hard error** (raise, no
silent fallback) if `bit_depth != 8`, `color_type != 6`, `compression != 0`,
`filter_method != 0`, or `interlace != 0`; per-scanline filters 0–4 (None/Sub/Up/
Average/Paeth) undone exactly per the research notes §3; pixel-count cross-check
catches any reconstruction bug before a bbox is reported.

---

## Measured values — PENDING (run blocked, see run status)

**None of the cells below are measured.** They are placeholders to be filled from the
probe's printed `observed` block. Do not read them as measurements (same rule as
`portrait_probe_notes.md`'s placeholder cells).

| name | decode_ok (96×128 RGBA) | bbox_raw | bbox_thresh8 | bottom_gap_raw | h_center_offset_raw | opaque_raw | opaque_thresh8 |
|---|---|---|---|---|---|---|---|
| west_poison | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** |
| north_beggar | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** |
| east_heretic | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** |
| south_emperor | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** |
| central_divine | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** |
| yang_guo | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** | **PENDING** |

### Expected values (from the handoff `WUXIA_ART_HANDOFF.md` — EXPECTED, NOT measured)

These are the recorded expectations the probe should be checked against. Any deviation
is a **finding to report verbatim, never to "fix"** (no redraw, no threshold change):

| name | expected bbox / defect |
|---|---|
| east_heretic | `top == 0` is **expected** — known defect (§四.3): antenna tips touch the top edge after crop. Not a geometry bug. |
| all six | `bottom_gap ≈ 0` (post-process is **bottom-aligned**) and `h_center_offset ≈ 0` (post-process is **horizontally centred**) — per handoff §三.4. |
| central_divine | very pale / near-transparent — if its alpha bbox is unexpectedly tiny or empty at threshold 8, that is a finding about the art (handoff §四.2), still recorded, still not folded into a pass. |
| all six | transparent-pixel share measured 47.8%–66.8% after `remove_bg` (handoff §三.5); border flood-fill repaired interior holes 0–6770 px (handoff §六) — so no interior holes are expected, but per-image counts are recorded, not assumed. |

---

## Probe source (the transient instrument — run it, transcribe, then delete)

```python
"""TRANSIENT probe — tests/test_tmp_alpha_bbox_probe.py (never committed)."""
import struct, zlib
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PNG_DIR = REPO_ROOT / "assets" / "characters"
NAMES = ["west_poison", "north_beggar", "east_heretic",
         "south_emperor", "central_divine", "yang_guo"]

def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc: return a
    if pb <= pc: return b
    return c

def decode_png_rgba8(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path.name}: not a PNG")
    pos, width, height, idat = 8, None, None, b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos+4])[0]
        ctype, cdata = data[pos+4:pos+8], data[pos+8:pos+8+length]
        if ctype == b"IHDR":
            (width, height, bit_depth, color_type, compression,
             filter_method, interlace) = struct.unpack(">IIBBBBB", cdata)
            if bit_depth != 8: raise ValueError(f"{path.name}: bit_depth {bit_depth}")
            if color_type != 6: raise ValueError(f"{path.name}: color_type {color_type}")
            if compression or filter_method: raise ValueError(f"{path.name}: bad cm/fm")
            if interlace: raise ValueError(f"{path.name}: interlaced unsupported")
        elif ctype == b"IDAT":
            idat += cdata
        pos += 12 + length
        if ctype == b"IEND": break
    if width != 96 or height != 128:
        raise ValueError(f"{path.name}: {width}x{height}, want 96x128")
    raw = zlib.decompress(idat)
    bpp, stride = 4, width * 4
    if len(raw) != height * (stride + 1):
        raise ValueError(f"{path.name}: bad raw length")
    recon, prev = [], [0]*stride
    for r in range(height):
        ft = raw[r*(stride+1)]
        row = raw[r*(stride+1)+1:(r+1)*(stride+1)]
        out = [0]*stride
        for c in range(stride):
            v, left = row[c], out[c-bpp] if c >= bpp else 0
            up, upleft = prev[c], prev[c-bpp] if c >= bpp else 0
            if ft == 0: pred = 0
            elif ft == 1: pred = left
            elif ft == 2: pred = up
            elif ft == 3: pred = (left + up) // 2
            elif ft == 4: pred = _paeth(left, up, upleft)
            else: raise ValueError(f"{path.name}: filter {ft}")
            out[c] = (v + pred) & 0xFF
        recon.append(out); prev = out
    if sum(len(r)//4 for r in recon) != width * height:
        raise ValueError(f"{path.name}: pixel count mismatch")
    return width, height, recon

def measure(path, threshold):
    w, h, recon = decode_png_rgba8(path)
    xs, ys, opaque = [], [], 0
    for y, row in enumerate(recon):
        for x in range(w):
            a = row[x*4+3]
            if a > threshold or (threshold and a >= threshold):
                xs.append(x); ys.append(y); opaque += 1
    if not xs:
        return {"bbox": None, "bottom_gap": None, "h_center_offset": None,
                "opaque_count": 0, "pixels_ok": w*h}
    left, right, top, bottom = min(xs), max(xs), min(ys), max(ys)
    return {"bbox": (left, top, right, bottom), "bottom_gap": 127-bottom,
            "h_center_offset": (left+right)/2.0 - 47.5, "opaque_count": opaque,
            "pixels_ok": w*h}

def run_probe():
    rows = {}
    for name in NAMES:
        p = PNG_DIR / (name + ".png")
        m0, m8 = measure(p, 0), measure(p, 8)
        rows[name] = {"decode_ok": "96x128 RGBA", "bbox_raw": m0["bbox"],
                      "bbox_thresh8": m8["bbox"], "bottom_gap_raw": m0["bottom_gap"],
                      "h_center_offset_raw": m0["h_center_offset"],
                      "opaque_raw": m0["opaque_count"], "opaque_thresh8": m8["opaque_count"]}
    return rows

def test_alpha_bbox_probe():
    rows = run_probe()
    lines = [f"{name}: " + " | ".join(f"{k}={v}" for k, v in rows[name].items())
             for name in NAMES]
    assert False, "ALPHA_BBOX_RESULTS\n" + "\n".join(lines)
```

Run: `python3 -m pytest tests/test_tmp_alpha_bbox_probe.py` → the always-false assert
prints the full `ALPHA_BBOX_RESULTS` block. Transcribe every value into the measured
table above, then `delete_file tests/test_tmp_alpha_bbox_probe.py` (it must not be in
the committed tree).

---

## No-commit guard / why the probe is not committed

Per the task card and design C7-M2, the probe is a **one-off transitional pytest file**:
written → run → values transcribed → deleted, all within the task. Committing a pinned
version is exactly the optional future nail (a) in `design/30_presentation.md`'s
texture-rect blind-spot record, which is **owner-decision-only and is NOT landed this
round** (research notes §7). This notes file is the durable record; the probe is not.

## Edge cases this probe is built to report (never silently pass)

- **All-transparent decode** → `bbox = None`, reported explicitly (never a pass).
- **Antialiased fringe / dust** → both raw (`alpha>0`) and threshold-8 (`alpha>=8`)
  bboxes recorded side by side.
- **Interlace / colortype≠6 / bit_depth≠8** → hard `raise`, no silent fallback.
- **Off-by-one filter reconstruction** → pixel-count == `96*128` cross-check inside
  `decode_png_rgba8` aborts before any bbox is reported from a corrupt decode.
- **Interior holes** not expected (border flood-fill applied, handoff §六) but per-image
  opaque counts are recorded, not assumed.
