# Pitfalls (learned the hard way)

## Polarization order

- WSClean assumes standard pol order by index (verified: predict places V at indices
  1,2 regardless of `CORR_TYPE`; gridding order-dependent). Non-standard orders
  (e.g. `[XX,YY,XY,YX]`) scramble Q/U/V and bias I. **Reorder once to
  `[XX,XY,YX,YY]` + relabel before any WSClean work; validate with reordered-vs-original
  dirty images (must correlate +1.0).** Slow/standard orders are usually already standard.
- Stokes codes 9–12 are **linear** XX/XY/YX/YY (not RR/RL/LR/LL). Check `Stokes.h`, don't guess.
- Caltables often carry only `[XX,YY]`. Null-pol test to prove no X/Y swap before trusting V sign.

## DP3 specifics

- `predict` does **not** materialize `MODEL_DATA` (neither standalone nor bare combined
  call in our tests). Use **WSClean `-predict`** to fill it (verify cross-hands for V models).
- Combined `predict+gaincal` in one DP3 call streams correctly once MODEL_DATA exists.
- New-MS outputs (`msout=<path>`) can only write `DATA`; in-place (`msout=.`) can write
  other columns. Plan column flow accordingly (calibrate into CORRECTED_DATA in place;
  subtract into new MS DATA).
- Frequency interpolation (`linear`) across mismatched channelizations works; verify by
  in/out ratio parity against a reference dataset.
- Opening hundreds of MS hits the fd limit → `ulimit -n 65536`.

## Calibration strategy

- Prefer transferred solutions from stable references over fresh solves. Fresh solves need
  STACKED high-SNR data; single snapshots return zeros/garbage/nondeterministic phases.
  Always validate (finite majority, sane scatter, rerun stability, imaging improvement).
- Global-median gain ratios are noise-biased on faint data (faint baselines inflate ratios
  ~1e2). Solve on high-SNR subsets (long baselines on bright calibrators, short baselines
  for bright Sun) and cross-check; per-antenna gain = sqrt(baseline ratio) for uniform arrays.
- Diagonal solves never touch cross-hands: V gains/leakage need full-Jones/polcal, and
  I-model subtraction never cleans V. Don't expect them to.
- `chgcentre` Dec needs `.` separators (`-14.34.35`), not colons, or it aborts.

## Imaging and spectra

- Snapshot (ms-scale) images are sidelobe-dominated; stack ~0.1–1 s (after bright-source
  removal) for clean disks. More time helps SNR, not UV filling (Earth rotation negligible).
- Joint-IQUV overcleans Q/U into checkerboards on faint fields; single-pol V (and I) are
  more trustworthy. Use I-derived source lists; WSClean won't write V source lists.
- V/I needs matched apertures and high SNR: whole-image sums mix bipolar lobes/sidelobes
  (fake flips), single pixels are noisy. Compare burst-core apertures and morphology, not
  mixed statistics. Genuine sign evolution (e.g. +→− within bursts) exists — don't confuse
  it with calibration flips.
- `-channels-out` on multi-MS joints channelization (use per-stream for clean ~2ch outputs
  plus a free MFS); count includes MFS files.
- Beam scalar corrections are positive-real (can't flip signs) and correct only the phase
  center; off-axis fluxes need direction-dependent treatment (peeling). Beamformer
  (total-power) vs interferometer (resolved) weight bipolar structure differently — expect
  different net V/I; compare lobe-to-lobe, not beam-vs-pixel.
- Concat splits FIELD tables when phase centers drift (even ~1″); use direction tolerance
  to merge, else downstream tools complain about multiple fields.
- `casatasks.tclean` on snapshot LWA MS can return empty images without clear errors;
  prefer validated WSClean paths once established.

## Centralized pipeline (calim2) — ops

- **Output dirs are keyed by LST hour**, not UTC: `<UTC date>/<floor(LST)>h/`
  (07:02 UT → `21h`; daily UTC h10/h11 runs → `02h`/`03h` in late Sept). Look for
  the confusion when locating results.
- Full-sky WSClean keeps dying with `std::bad_alloc` under memory pressure (even
  with `-mem` caps; 41–64 MHz and 64–82 MHz both on 2026-09-30) — the run still
  reports **SUCCESS**, so check the log for failed bands before trusting the
  3-colour/full-sky products.
- The production watcher is a **bare bash process** (no cron/systemd): after a
  reboot/session end it stays dead until restarted; `pgrep -af watch_calib_auto.sh`
  first when runs stop appearing.
- Take `calibration_<date>_<LST>.B.flagged` (refined table) downstream, never the
  raw `.B`; the daily solve derives fresh bandpass solutions — the
  `reference/bandpass/` dir is legacy and only the *delay* reference is loaded.
- Fully-flagged SPWs are auto-excluded from imaging (SPW 0 / 13 MHz commonly is);
  its absence from products is normal, not a failure.
- Latent bug: the single-integration fallback path reads
  `config.INTEGRATION_DURATION_SEC`, which `pipeline_config.py` does not define —
  harmless for the standard 6-integration runs, fatal for 1-integration inputs.
