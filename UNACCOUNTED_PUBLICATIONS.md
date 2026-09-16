# Unaccounted publications on this branch

Every publication here is supposed to be traceable, from the commit itself, to
one gate run that exited 0 on a commit that was on master **at the time**. The
two below are not. They are recorded here, and in the commits that added these
entries, because a publication that already happened cannot be undone and must
not be quietly re-judged.

In both cases a gate did run and exited 0. What was missing is the other half:
master did not contain the candidate when the bytes went out. An ancestry test
run today answers yes for both, because both feature branches have been merged
since -- which is why the instants are written down rather than recomputed.

Nothing on this page repairs a publication or makes one lawful in retrospect.

## 446a5e319826974df56fad1ae9d585d5c05f3654

- Published 2026-09-16T11:48:17+00:00; payload withdrawn the same day by `df170c54`.
- Built from `71eb925dad529619ede4bf1e752386e13cc8729b`.
- Gate `gq-20260916T104715Z-778d8285`: `gate.gate.head` = that candidate,
  `gate.gate.exit` = 0, finished 2026-09-16T11:48:07Z.
- The mainline first contained the candidate at
  `f6c54610c36f2b3712e535845a2529039575b694`, committed 2026-09-16T12:49:41+00:00
  -- **after** the publication.
- `index.pck` sha256 `74af5dcd0e9459b1bcee6ccd8bbb5893102c47b2d1120ee0a2d5b67834ecadfc`
- `index.wasm` sha256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`
- The publication commit carries no gate ticket, no gated commit and no mainline
  tip, so none of the above can be read from it alone.
