# Centralized calibration pipeline (calim2)

The OVRO-LWA *centralized* (production) calibration of **slow** correlator data:
one hour-slice at a time → concatenated MS → sky model → bandpass table + QA,
archived per UTC date and **LST hour**.  Code by the LWA calibration group
(`ovro-lwa/ovro-lwa-calibration-pipeline`, production branch `qa-md5-fix`),
bash launchers + CASA-6 Python orchestrator.  This is *not* the triggered
fast-dump path (see [bufferdump.md](bufferdump.md)) — slow data only.

## One run in one breath

Hour-slice = **6 integrations × 16 sub-bands = 96 single-integration MS**
(`<YYYYMMDD_HHMMSS>_<sb>.ms.tar`, 10.031 s each, 13.4–86.9 MHz, 192 ch ×
23.926 kHz per sub-band).  Steps (tool in parentheses):

0. **bash layer**: select 6 integrations (first of the hour; some launchers pick
   the first ≥ a `START_TIME`; hour 03 uses the 03:02–03:04 slots) → extract tars
   to `/fast`.
1. **Data preparation**: CASA `concat` → `FIELD_ID=0` (casacore) → `chgcentre`
   to the **zenith** phase centre → antenna-health flagging from the MNC
   database (`development` env helper: `mnc.anthealth` + `lwa_antpos`; a typical
   day → ~130 bad antennas, unioned with the static additional list) → AOFlagger
   with strategy `LWA_opt_GH1.lua`.
2. **Sky model**: A-team apparent fluxes (primary-beam corrected) → CASA
   component list (tabular spectra) → `ft usescratch=True` → `MODEL_DATA`.
3. **Bandpass**: `bandpass(bandtype='B', refant='283', uvrange='>5lambda,<350lambda',
   solint='inf', combine='obs,scan,field', minsnr=3)` → six-step refinement of
   the table (normalise 40–55 MHz → channel scatter >7× median → median
   template, medfilt 51 → deviations >7·IQR/1.349 → per-antenna gain outliers →
   iterative 3σ clip ≤15× → channel quorum >50 %) → `applycal` →
   `CORRECTED_DATA`.
4. **Delay diagnostics**: `gaincal(gaintype='K', scan='1', spw='6~15')` (≥41 MHz
   only) vs the LST-nearest reference table (±8 h; currently only LST 20h);
   |Δτ| > 100 ns → warn; problems folded onto SNAP2 rows (R3–R13), >50 % bad →
   CRITICAL log.  Non-fatal.
5. **Imaging** (WSClean 3.4, diagnostics): per modelled source spectrum (512²)
   and scintillation (per-integration) images; zenith full-sky in 3 bands
   (4096², auto-mask/auto-threshold).  Fully flagged SPWs are excluded (SPW 0 /
   13 MHz often is).  Imaging failures are warnings, not run failures.
6. **QA**: imstat + imfit beam-corrected spectra vs intrinsic models, delay
   comparison plots, positional offsets, time-resolved spectra, 3-colour RGB,
   reportlab PDF; finalize → `successful|unsuccessful/<ts>`.

Deliverable = `calibration_<date>_<LST>.B.flagged` (plus raw `.B` and diagnostic
`.K`) in `<date>/<LST>h/successful/<ts>/tables/`; the concatenated MS is deleted
on success, only `*.ms.flagversions` remains.

## Sky model

- primaries (from `primary_calibrator_flux_models.npz`, 3072 channels):
  CygA (Baars 1977, 8th-order log-poly), CasA (definitive 2023.5 spectrum ×
  (1−0.0046)^(t−2023.5)), VirA (log-poly), TauA (970 (ν/GHz)^−0.30 ×
  (1−0.0016)^(t−1985.5));
- secondaries: 21 3C sources, Scaife & Heald 2012 log-polys (S150, c1, c2);
- beam: `OVRO-LWA_MROsoil_updatedheight.h5`, zenith-normalised |E|² power;
  apparent flux = intrinsic × P(ν, zenith angle, azimuth);
- source included iff elevation > 20° **and** max apparent flux ≥ 1000 Jy
  (typically CygA and/or CasA at night LSTs; the rest are CSV-logged only).

## Key paths (calim2 = `lwacalim02`, UTC, user `pipeline`; peijinz has read access)

```
inputs      /lustre/pipeline/slow/<sb>/<date>/<HH>/<stamp>_<sb>.ms.tar
code        /opt/devel/nkosogor/nkosogor/ovro-lwa-calibration-pipeline/
launchers   /fast/pipeline/calibration/*.sh  +  logs/  +  watch_state/
staging     /fast/pipeline/calibration/<date>/<HH>/            (deleted on success)
work tree   /fast/pipeline/calibration/<date>/<LST>h/working/<ts>/{ms,QA,tables}
archive     /lustre/pipeline/calibration/results/<date>/<LST>h/{successful|unsuccessful}/<ts>/
envs        conda py38_orca_nkosogor (main, hard pre-flight check) + development (MNC)
tools       /opt/bin/{wsclean 3.4, aoflagger 3.2, chgcentre}
```

The automation is `watch_calib_auto.sh` (a **bare bash process**, no
cron/systemd): polls every 300 s for UTC hours 10 + 11, requires ≥6 items per
sub-band stable for 600 s, then runs `calibration.sh` with
`DATE_OVERRIDE`/`HOURS_OVERRIDE`, recording `watch_state/<date>_<hour>.done|.failed`.

## Inspecting runs (on calim2)

```bash
pgrep -af watch_calib_auto.sh          # watcher alive? (dies with its session/reboot)
tail -20 /fast/pipeline/calibration/logs/watch_calib_auto.log
ls /lustre/pipeline/calibration/results/<date>/     # one dir per LST hour
# bash-layer log:  /fast/pipeline/calibration/logs/calib_<date>_<hour>*.log
# python log:      <run>/QA/pipeline_<date>_<LST>.log   (DEBUG level)
grep -E "status: SUCCESS|FAILURE|std::bad_alloc" <run>/QA/pipeline_*_<LST>.log | tail
```

`scripts/calim2_calib_status.sh` wraps this: watcher status + last few days of
results + tails of the newest run logs.

## Ops gotchas

- **LST labels, not UTC hours**: output dirs are
  `<UTC date>/<floor(LST)>h/` (07:02 UT → `21h`; the recent daily runs at
  UTC 10/11 → `02h`/`03h`); don't look for "hour 07".
- WSClean full-sky can die with `std::bad_alloc` under memory pressure (even
  with `-mem` caps) — the run still reports **SUCCESS**; check the log for the
  failed band before trusting the 3-colour image.
- The watcher is unsupervised: after a reboot it stays dead until someone
  restarts it in a session (a `systemd --user` unit is the natural fix).
- Latent bug: the single-integration fallback path references
  `config.INTEGRATION_DURATION_SEC`, which is not defined in
  `pipeline_config.py` (only in `process_archive.py`) — only triggers for
  1-integration inputs.
- The daily bandpass solve derives fresh solutions; `reference/bandpass/` is
  legacy — only the **delay** reference table is actually loaded (Step 4).
- Reusing the products downstream: take `.B.flagged` (flags already merged into
  the table), not `.B`; table flags propagate to data flags only through its
  `applycal`.

## Deeper material (local Mac)

Full technical note with all equations, per-step flow charts and the
2026-08-27/21h worked example: `~/dev/astro-calibration-pipe/texdoc/`
(`main.tex` + `fig/`), session notes `~/dev/astro-calibration-pipe/mem.md`,
raw log snapshot `~/dev/astro-calibration-pipe/remote_logs/`.
