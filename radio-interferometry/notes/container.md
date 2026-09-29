# Container testing (machines without the software environment)

Use the `lwasolarproc` container to test pipeline code on any machine with
podman/docker — no CASA/DP3/WSClean install needed.

## Image

- `docker.io/peijin/lwasolarproc:linc` (only tag; built on `astronrd/linc`).
- Contains: `lwasolarproc` package + entry points (`lwasolarproc-fullband`,
  `lwasolarproc-realtime`), WSClean 3.7, DP3 6.6.0, `lwa-solar-util`.
- Missing: **no CASA** (`casatools`/`casatasks`); CASA-dependent code paths
  fail inside the image. DP3 is 6.6.0 (host envs may pin 6.5.1 — note drift).

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

## Smoke test (new machine)

```bash
podman pull docker.io/peijin/lwasolarproc:linc
podman run --rm docker.io/peijin/lwasolarproc:linc \
  'python3 -c "import lwasolarproc; print(lwasolarproc.__file__)"'
podman run --rm docker.io/peijin/lwasolarproc:linc 'wsclean --version'
podman run --rm docker.io/peijin/lwasolarproc:linc 'DP3 --version'
```

## Data test (DP3 + WSClean on a real MS)

Mount the MS read-only plus a writable scratch dir; copy the MS to scratch
first if a step must write in place (e.g. DP3 `msout=.`):

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
- Full status/verification log: `container.md` in the workspace root.
