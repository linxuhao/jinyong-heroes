# Archived public front matter

Bodies that were published at the Pages root before this publisher
owned the root, kept verbatim so nothing published ever disappears.
Each row is `archived path` | sha256 of the bytes.

Correction, kept here because a public record may not quietly get
clean: the claim above was once false on this page. Between
published commits `0d1541e` and `1ef00ddc`, the annotation
that names which root file an archived body replaced was erased
from every row below. `1ef00ddc` is the publish that erased it:
it archived
nothing, so it rebuilt this ledger from the archive directory
alone and wrote the rows back with an empty annotation
(ARCHIVE.md `944c2d6415a53c6d...` became `89c61c1f094be36b...`).
The archived bodies and their digests never changed; what went
missing was which root file each one superseded. Those
annotations were restored from the bytes of `0d1541e`, and a
republish now inherits them instead of emptying them.

- `notes/archive/README.md` | `4313d24a4ed83e89e4e5d2b25b0baa6beea51bd308c7966da5a0ab68d9c38950` (superseded root `README.md`)
- `notes/archive/index.md` | `065d2355320438f62f9e9bef61e6f6e0a3f2483cd5f1d1d83c855160f24baeeb` (superseded root `index.md`)
