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

## calim2 (lwacalim02)

- Host: `lwacalim02` (Linux EL8, x86_64), UTC timezone, ~500 GB RAM. Pipeline files
  are owned by user `pipeline`; `peijinz` has read access (read-only etiquette).
- Role: OVRO-LWA **centralized (production) calibration** of slow-correlator data.
  A long-lived bash watcher (`watch_calib_auto.sh`) launches hourly runs
  automatically (UTC hours 10 + 11 daily); see
  [central-calibration.md](central-calibration.md).
- Code: `/opt/devel/nkosogor/nkosogor/ovro-lwa-calibration-pipeline` (git
  `ovro-lwa/ovro-lwa-calibration-pipeline`, production branch `qa-md5-fix`;
  local uncommitted edits + `.bak_*` files present).
- Conda envs (under `/opt/devel/pipeline/envs/`): `py38_orca_nkosogor` — main
  pipeline env (CASA 6 casatools/casatasks; hard pre-flight check on
  `CONDA_DEFAULT_ENV`); `development` — MNC antenna-health helper (`mnc`,
  `lwa_antpos`).
- Tools at fixed paths: `/opt/bin/{wsclean (3.4), aoflagger (3.2), chgcentre}`;
  AOFlagger strategy `/lustre/ghellbourg/AOFlagger_strat_opt/LWA_opt_GH1.lua`.
- Data layout: inputs `/lustre/pipeline/slow/<sb>/<date>/<HH>/*.ms.tar`; work +
  launchers + logs `/fast/pipeline/calibration/`; results archive
  `/lustre/pipeline/calibration/results/<date>/<LST>h/{successful|unsuccessful}/<ts>/`;
  beam model `/lustre/pipeline/beam-models/OVRO-LWA_MROsoil_updatedheight.h5`.
- Etiquette: don't kill/restart the watcher or touch `/fast` staging while a run
  is active; logs are written by the pipeline itself (`tee`), read them read-only.
