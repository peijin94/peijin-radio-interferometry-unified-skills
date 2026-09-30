# Container testing (machines without the software environment)

Use the `lwasolarproc` container to test pipeline code on any machine with
podman/docker — or Apple's `container` on macOS 26 — no CASA/DP3/WSClean install
needed.

## Image

- `docker.io/peijin/lwasolarproc:linc` (only tag; built on `astronrd/linc`).
- Contains: `lwasolarproc` package + entry points (`lwasolarproc-fullband`,
  `lwasolarproc-realtime`), WSClean 3.7, DP3 6.6.0, `lwa-solar-util`.
- Missing: **no CASA** (`casatools`/`casatasks`); CASA-dependent code paths
  fail inside the image. DP3 is 6.6.0 (host envs may pin 6.5.1 — note drift).
- **amd64-only** — there is no arm64 manifest.

## Golden rule: one quoted string

`ENTRYPOINT` is `bash -lc`, so the command must be a **single quoted string**.
Separate args silently misbehave (e.g. `run img python3 -c "…"` launches a
bare `python3` that exits 0 doing nothing).

```bash
# right
podman run --rm docker.io/peijin/lwasolarproc:linc 'lwasolarproc-fullband --help'
# WRONG (silent no-op)
podman run --rm docker.io/peijin/lwasolarproc:linc lwasolarproc-fullband --help
```

## Apple Container (macOS 26)

Same image, but two flags are mandatory and one default will kill long jobs.

- Install: there is **no Homebrew cask** for this. Download the signed pkg from
  `https://github.com/apple/container/releases`
  (`container-<ver>-installer-signed.pkg`) and `open` it — the admin password is
  entered in the macOS Installer dialog. Then run
  `container system kernel set --recommended` **before** `container system start`;
  otherwise start aborts with `Error: failed to read user input` (the kernel
  prompt needs a TTY).
- Because the image is amd64-only and `container run` defaults to the host arch,
  a bare run fails with a message that never names the fix:
  `Error: platform linux/arm64`. Always pass `--platform linux/amd64 --rosetta`
  (Rosetta must be installed on the host). The *pull* succeeds either way, so a
  good pull is not evidence the image is runnable.
- The container VM defaults to **1 GB RAM** (`container system property list`
  shows `[container] memory = "1gb"`). DP3 on a full MS dies with **exit 137
  (SIGKILL)** mid-progress-bar and no error text. Add `-m 6g`. Treat exit 137
  as OOM before debugging the payload.
- Bind mounts are `-v host:container`, same shape as podman. The quoted-string
  rule still applies.

```bash
container run --rm --platform linux/amd64 --rosetta -m 6g \
  -v /tmp/ctest:/work docker.io/peijin/lwasolarproc:linc 'DP3 /work/run.parset'
```

## Known defect: python-casacore is too old for the image's numpy

Two different casacore things live in the image — do not conflate them:

- **C++ casacore 3.8.0** (`/usr/local/include/casacore/casa/version.h`;
  `libcasa_*.so.9` in `/usr/local/lib`). Used by DP3 and WSClean. Fine.
- **python-casacore 3.5.3.dev36+g6bb837f7d** — the python bindings, and the
  broken one. It predates numpy 2.

The image ships numpy 2.4.6, so `import casacore.tables` succeeds but the first
array access fails — the numpy C API is loaded lazily:

    RuntimeError: PycArray: failed to load the numpy API

The inspection snippets in `EXAMPLES.md` therefore do **not** run out of the box.

Fix by upgrading the bindings, not by downgrading numpy:

```bash
pip install -U python-casacore     # 3.5.3.dev36 -> 3.8.1
```

Verified: after the upgrade numpy stays 2.4.6 and reading the MS works
(62,128 rows, `DATA` shape (rows, 192, 4) complex64, finite frac 1.0,
192 chan 50.148–54.718 MHz). `pip install "numpy<2"` also works but breaks
`zarr`, which requires numpy>=2 — so upgrade the bindings instead.
Proper fix: bump python-casacore in `container/Dockerfile`.

## Smoke test (new machine)

```bash
podman pull docker.io/peijin/lwasolarproc:linc
podman run --rm docker.io/peijin/lwasolarproc:linc \
  'python3 -c "import lwasolarproc; print(lwasolarproc.__file__)"'
podman run --rm docker.io/peijin/lwasolarproc:linc 'wsclean --version'
podman run --rm docker.io/peijin/lwasolarproc:linc 'DP3 --version'
```

Expected: `/opt/lwasolarproc/lwasolarproc/__init__.py`, `WSClean version 3.7`,
`DP3 6.6.0`.

## Data test (DP3 + WSClean on a real MS)

Mount the MS read-only plus a writable scratch dir; copy the MS to scratch
first if a step must write in place (e.g. DP3 `msout=.`). Keep `showcounts=false`:
the default per-baseline/per-channel flag table is ~600 kB of log per run and
buries the actual result.

```bash
mkdir -p /tmp/ctest && cp -r /path/to/test.ms /tmp/ctest/ && cp /path/cal.h5 /tmp/ctest/
podman run --rm -v /tmp/ctest:/work docker.io/peijin/lwasolarproc:linc \
  'DP3 msin=/work/test.ms msin.datacolumn=DATA msout=. msout.datacolumn=CORRECTED_DATA \
   steps=[ac] ac.type=applycal ac.parmdb=/work/cal.h5 ac.solset=sol000 \
   ac.steps=[amp,phase] ac.amp.correction=amplitude000 ac.phase.correction=phase000 \
   verbosity=quiet showcounts=false; echo DP3EXIT=$?'
podman run --rm -v /tmp/ctest:/work docker.io/peijin/lwasolarproc:linc \
  'wsclean -j 2 -quiet -size 128 128 -scale 78.125arcsec -pol I -niter 10 \
   -data-column CORRECTED_DATA -name /work/smoke /work/test.ms && ls /work/smoke*.fits'
```

## Verified under Apple Container

Apple Container 1.5.0 / macOS 26.5.2, M-series, invoked as
`--platform linux/amd64 --rosetta -m 6g`:

- Smoke test above: all three pass.
- `/nas8/lwa/event-MS/20260903LongType35pol/50MHz/22/20260903_220155_50MHz.ms.tar`
  (192 chan 50.15–54.72 MHz, 352 ants, 62,128 rows, one 10.03 s time slot,
  `CORR_TYPE` `[9,10,11,12]` = linear):
  - DP3 `steps=[count]` — 1.98 s, exit 0, 0% flagged.
  - DP3 `steps=[averager] averager.freqstep=4` — 6.16 s, exit 0; re-reading the
    output MS confirms 192 → 48 channels.
  - WSClean `-size 256 256 -scale 60arcsec -pol I -niter 30` — exit 0, all five
    planes written (dirty/image/model/psf/residual), 256×256, `JY/BEAM`,
    `RA---SIN`/`DEC--SIN`, non-zero data (PSF peak 1.0).
  - Same result on `-data-column CORRECTED_DATA` after DP3 wrote that column.

## When to use / limits

- Use for: CI-style checks, collaborator machines, testing PRs or fresh
  checkouts without the full LWA env.
- `lwasolarproc-realtime` needs its slow-data tree, caltables, and a writable
  proc-tmp mounted in (see upstream `container/README.md`); mount `/dev/shm`
  or a real scratch dir if shared memory is restricted.
- Image code can lag repo HEAD (it bakes the package at build time) — check
  `git -C /opt/lwasolarproc rev-parse HEAD` inside, rebuild if stale:
  `podman build -f container/Dockerfile -t lwasolarproc:linc .`
  from the repo root (build context must be the root, not `container/`).
- A single event MS is ~10 s of data: it exercises the software paths, not
  calibration quality. Do not read flux or position fidelity from it.
- Full status/verification log: `container.md` in the workspace root.
