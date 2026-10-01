---
name: radio-interferometry
description: Calibrate and image radio-interferometer visibilities (CASA Measurement Sets) with DP3/CASA/WSClean. Use when working with Measurement Sets, bandpass/selfcal calibration, gain transfer, A-Team anchoring, full-sky modeling, polarization (IQUV/V sign), spectral imaging, dynamic spectra, or triggered buffer-dump fast data.
---

# radio-interferometry

## Quick start

```bash
source <env-with-casa-dp3-wsclean>   # e.g. LWA: source /fast/rtpipe/use_lwa.sh
python scripts/reorder_ms_pol.py --src-dir ms/ --dst-dir ms_std/  # standardize pol order first
```

Standard chain per dataset: inspect → bandpass (primary cal) → flag → subtract
bright sources → transfer/derive selfcal → phase-center → image (MFS/channels-out)
→ postprocess → spectra. Details: [REFERENCE.md](REFERENCE.md).

## Workflows

1. **Inspect data** — antennas, times, channels, pol order, flags; confirm
   `CORR_TYPE` is standard `[XX,XY,YX,YY]` (reorder if not).
2. **Bandpass** — DP3 `applycal` of primary H5Parm/CASA table (amp+phase, interpolate
   in frequency); verify in/out ratio matches expectation.
3. **Selfcal** — prefer transferred solutions from a stable reference; solve fresh only
   on stacked high-SNR data (single snapshots do not converge); validate phases
   (finite majority, sane scatter) before applying.
4. **Bright-source removal** — full-sky model → mask far-from-target → DP3 predict
   subtract (new MS writes DATA only).
5. **Image** — WSClean MFS or channels-out; Sun/small-FOV or full-sky; keep models.
6. **Validate** — positions (A-Team), flux scale vs reference, V sign vs beamformer
   at high-SNR peaks, dynamic range/background, matched apertures for pol.

## Triggered buffer dumps (fast data)

Same chain, plus: copy (never touch raw); expect different path gain (verify, don't
assume); stack in time for SNR (snapshots image poorly alone); subtract bright
sources (essential — sidelobes dominate snapshots); validate V sign and scale
against beamformed spectra at peaks (beware sidelobe/aperture/bipolar effects).

## Gotchas (see PITFALLS.md)

Non-standard pol order breaks WSClean; DP3 predict won't materialize MODEL_DATA
(use WSClean-predict); global-median gains are noise-biased; joint-IQUV overcleans;
Stokes codes 9–12 are linear; beam scalar corrections can't flip V sign.

## Examples

Copy-paste commands: [EXAMPLES.md](EXAMPLES.md). Reusable drivers: [scripts/](scripts/).

## Notes (deeper dives)

- [notes/envs.md](notes/envs.md) — machines and environments.
- [notes/container.md](notes/container.md) — container testing on machines
  without the software environment (podman/docker, quoting gotcha, smoke tests).
- [notes/calibration.md](notes/calibration.md) — general calibration notes.
- [notes/central-calibration.md](notes/central-calibration.md) — the OVRO-LWA
  *centralized* production calibration pipeline on calim2 (hourly slow-data
  runs: steps, sky model, paths, how to inspect runs, ops gotchas).
- [notes/squint.md](notes/squint.md) — beam-squint bipolar diagnosis and calibration plan.
- [notes/primarybeam.md](notes/primarybeam.md) — beam models and correct use.
- [notes/bufferdump.md](notes/bufferdump.md) — triggered fast-dump MS handling.
- [notes/polarization.md](notes/polarization.md) — V conventions, solve rules,
  RR/LL, V magnitude-gap decomposition.
