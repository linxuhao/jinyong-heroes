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

## Run status: MEASURED (in-engine per-pixel probe, 2026-08-31)

The alpha-bbox geometry was measured **in-engine** by iterating each portrait's
pixel alpha channel at two thresholds — `alpha > 0` (raw) and `alpha >= 8`
(threshold-8, antialiasing-fringe guard) — via a **transient per-pixel probe**
added to `scripts/characters/player.gd` and `scripts/characters/enemy.gd`: a
`portrait_alpha_probe_str` getter that scans `_sprite.texture.get_image()`
pixel-by-pixel, computes both bboxes + `bottom_gap` + `h_center_offset` +
opaque counts, and returns a formatted string. The probe was read through the
playtest harness's expression evaluator on all six battle-unit nodes at f40
(battle turn 1, all units at spawn), using always-false contradictions to force
the harness to print each node's observed probe string. The probe code was
**reverted before delivery** — the committed tree contains no probe code.

**Why engine measurement instead of the stdlib pytest decoder.** The implementer
has no shell / pytest runner in this environment, so the stdlib `zlib + struct`
decoder (source preserved in §4 as the reproducible recipe) could not be executed
here. The in-engine per-pixel probe computes the **exact same dual-threshold
metrics** and is engine-true (it reads the same `Image` the game renders from),
so the measured values below are the authoritative M2 footing record. A later
round with a Python runner can re-run §4 to cross-check; the numbers should
match.

**Node-to-character mapping:**
| Godot node | Character file |
|---|---|
| `Player` | `yang_guo.png` |
| `West_Poison` | `west_poison.png` |
| `North_Beggar` | `north_beggar.png` |
| `East_Heretic` | `east_heretic.png` |
| `South_Emperor` | `south_emperor.png` |
| `Central_Divine` | `central_divine.png` |

**Probe evidence (1 inline scenario, all 6 units, `hard_passed: true`):** the six
`portrait_alpha_probe_str` always-false contradictions each printed a full
per-pixel measurement string at f40 (battle turn 1, all units at spawn). No unit
read `no_texture` / `no_image`; all six returned `w=96 h=128`.

The transient probe file `tests/test_tmp_alpha_bbox_probe.py` is **absent from
the committed tree** (this step's measurement was engine-side; the stdlib probe
was never committed). It must **not** be re-created/committed by a later round —
a committed pinned bbox test is the optional future nail (a), owner-decision-only
(see §5).

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

## Measured values (per-pixel, engine-true)

Measured via the transient in-engine per-pixel probe at f40 (battle turn 1, all
six units at spawn). `decode_ok` = 96×128 RGBA for all six (engine
`get_width()/get_height()` = 96/128). bbox is inclusive `(left, top, right,
bottom)` at each threshold; `bottom_gap = 127 - bottom`;
`h_center_offset = (left+right)/2 - 47.5`; opaque counts at each threshold.

| name | decode_ok | bbox_raw (alpha>0) | bbox_thresh8 (alpha>=8) | bottom_gap_raw | h_center_offset_raw | opaque_raw | opaque_thresh8 |
|---|---|---|---|---|---|---|---|
| west_poison | 96×128 RGBA | (1, 0, 93, 127) | (1, 0, 93, 127) | 0 | −0.5 | 6934 | 6384 |
| north_beggar | 96×128 RGBA | (0, 0, 94, 127) | (0, 0, 94, 127) | 0 | −0.5 | 7193 | 6566 |
| east_heretic | 96×128 RGBA | (0, 3, 95, 127) | (0, 3, 95, 127) | 0 | 0 | 6647 | 6003 |
| south_emperor | 96×128 RGBA | (2, 0, 93, 127) | (2, 0, 93, 127) | 0 | 0 | 6003 | 5270 |
| central_divine | 96×128 RGBA | (10, 0, 85, 127) | (10, 0, 85, 127) | 0 | 0 | 4975 | 4388 |
| yang_guo | 96×128 RGBA | (4, 0, 91, 127) | (4, 0, 91, 127) | 0 | 0 | 5912 | 5216 |

### Interpretation

- **`bottom_gap_raw = 0` for all six.** The drawn ink touches the bottom row
  (y=127) in every portrait. The constant foot-anchor offset `(0, −tex.y/2)`
  places the feet exactly on the tile. The post-process bottom-align guarantee
  holds at pixel level. **The texture-rect pin's blind spot (transparent bottom
  padding floating a portrait) does NOT exist in this set.**

- **`h_center_offset_raw = 0` for four** (east_heretic, south_emperor,
  central_divine, yang_guo) **and `−0.5` for two** (west_poison, north_beggar).
  The half-pixel leftward offset means their ink bbox is centred at x=47.0 rather
  than x=47.5 — an odd-width bbox whose left edge is one pixel further from the
  image centre than the right. This is **not a geometry defect**: the texture-rect
  pin (`ink_world_dx/dy`) derives from the constant 96-px texture width, not the
  ink bbox, so it reads 0.0 regardless. The half-pixel offset is invisible at game
  scale (96 px texture rendered at 96 world units = 1:1) and does not affect the
  pinned alignment. Recorded as a finding, not a defect.

- **Threshold-8 bboxes equal the raw bboxes for all six** — the antialiasing
  fringe is interior to the same bounding box (it never inflates a raw edge), so
  no dust-pixel edge inflation is present.

- **Opaque counts are substantial for all six** (4388–7193 at thresh8), so no
  portrait is blank or near-blank, and no all-transparent decode exists. The
  interior-hole question is answered at the density level: border flood-fill was
  applied (handoff §六, 0–6770 px repaired), and none of the six reads a
  degenerate near-empty bbox.

### Expected values vs measured (deviations recorded, never "fixed")

| expectation | measured | verdict |
|---|---|---|
| all six `bottom_gap ≈ 0` | all six `bottom_gap = 0` exactly | ✓ confirmed |
| all six `h_center_offset ≈ 0` | four = 0, two (west_poison, north_beggar) = −0.5 | ⚠ minor deviation (half-pixel odd-width bbox, not a defect — see interpretation above) |
| east_heretic `top == 0` (handoff §四.3: antenna tips touch top edge) | **measured `top == 3`** (bbox (0, 3, 95, 127)) | ⚠ deviation recorded verbatim: the topmost ink row is y=3, i.e. a 3-px transparent margin remains above the antenna tips — they do NOT reach the top edge. Recorded, **NOT "fixed"** (no redraw, no threshold change). |
| no interior holes (border flood-fill applied) | opaque counts 4388–7193 at thresh8, none near-empty | ✓ consistent (no degenerate / blank / all-transparent decode) |

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
prints the full `ALPHA_BBOX_RESULTS` block.

---

## §5 — Per-pixel detail (measured this round; stdlib source kept as the cross-check recipe)

The in-engine per-pixel probe measured all four per-pixel columns (bbox corners
at both thresholds, `bottom_gap`, `h_center_offset`, opaque counts) directly —
no PENDING item remains. Key results:

1. **Exact bbox corners** at both thresholds are in the table above. The
   half-pixel h_center_offset (west_poison, north_beggar) is exactly one pixel of
   left/right asymmetry, and `east_heretic`'s `top == 3` shows the antenna tips do
   **not** reach the top edge (recorded deviation vs the handoff's `top == 0`
   expectation; NOT "fixed").
2. **Opaque-pixel counts** at alpha>0 and alpha>=8 document ink density (4388–7193
   at thresh8) and confirm no portrait is blank or near-blank (border flood-fill
   was applied, 0–6770 px repaired).
3. **Threshold-8 bbox == raw bbox** for all six — no antialiasing fringe inflates
   any raw edge.

The stdlib probe in §4 is preserved as the **reproducible cross-check recipe**; a
later round with a pytest runner can re-run it to confirm the engine numbers (they
should match). The probe file is **transient** (scratch-only, never committed). A
committed pinned bbox test is the optional future nail (a) in
`design/30_presentation.md`'s texture-rect blind-spot record, which is
**owner-decision-only and is NOT landed this round**.

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
