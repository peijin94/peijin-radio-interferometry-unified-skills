# Environments

One section per machine. No credentials, keys, or passwords are stored here —
only public paths, software, and operating etiquette. Append new envs as sections.

## calimsolar (current)

- Host: `lwacalim12` (Linux EL8, x86_64), 384 cores, ~755 GB RAM.
- Role: LWA solar realtime processing + offline reduction/imaging. A live realtime
  pipeline runs here (daytime heavy load); offline work must yield to it.
- Environment script: `source /fast/rtpipe/use_lwa.sh`
  - `LWA_ENV=/fast/rtpipe/env/lwa` (python + casatools/casatasks + python-casacore)
  - `UV_HOME=/fast/rtpipe/env/uv-bin`, DP3 6.5.1 at `/opt/dp3-6.5.1/bin/DP3`
  - WSClean 3.7, `chgcentre` on PATH; Julia depot configured by the same script.
  - Sets cache/config dirs (uv, casa siteconfig, matplotlib, sunpy runtime) — do not override.
- Typical layout: workspace root with `ms/` (raw, read-only), `MS_standard/`,
  `bcal/`, `gcal/`, `scripts/`, `proc/` (scratch), `imgs/`, plus a local pipeline clone.
- Etiquette: `nice -n 19 ionice -c3`, one heavy job (or few light threads) at a time,
  tmux + log files for long runs, `ulimit -n 65536` when opening hundreds of MS,
  never write/delete raw data dirs, resumable drivers (`.done` sentinels + manifests).
