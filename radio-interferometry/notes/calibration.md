# Calibration notes (general)

## Principles

1. Transfer stable solutions; solve fresh only on stacked high-SNR data.
2. Calibrate in order: bandpass → flag → subtract bright sources → selfcal →
   phase-center → image. Each stage validated before the next.
3. Never trust a solution you haven't validated (finite majority, sane scatter,
   rerun stability, imaging improvement).

## Bandpass (primary)

- DP3 `applycal` of the nearest covering table (amp+phase, interpolate in frequency).
- Table must span your frequencies; caltable pols (often `[XX,YY]` only) must map
  without X/Y swap — prove with a null-pol test (zero one pol in a copy; only the
  matching MS pol should go quiet).
- Confirm in/out amplitude ratio matches the expected path gain (compare to a
  reference dataset when the signal path is new).

## Selfcalibration

- Phase-only diagonal (`diagonalphase`, solint covering stable interval) first.
- Transferred solutions (from long integrations) beat fresh solves on short data:
  single snapshots return zeros/garbage/nondeterministic phases; stacked chunks are
  marginal (burst variability defeats solint=0). Validate and enforce thresholds.
- Per-antenna gain = sqrt(baseline ratio) for uniform arrays; global medians over
  faint baselines are noise-biased (use high-SNR subsets: long baselines on bright
  calibrators, short baselines for bright extended emission).
- Diagonal solves never touch cross-hands: Stokes V gains, leakage/D-terms, and X–Y
  refinements need full-Jones or polcal (Df/D, Xf) with polarized/unpolarized models.

## Bright-source removal

- Model (full-sky/FOV WSClean, `-save-source-list`) → mask far-from-target →
  DP3 `predict operation=subtract` into a new MS (new outputs write DATA only).
- Protect the target (e.g. exclude near-Sun components). Unpolarized calibrators
  (Cas A/Cyg A) anchor astrometry (<0.05 deg) and flux scale; subtracting I models
  does not clean V cross-hands.

## Amplitude scale and polarization sanity

- Cross-check path gain (raw medians), calibrated visibility medians, image peaks,
  and calibrator fluxes; decompose discrepancies (path gain × variability × imaging).
- V sign: validate against an independent beamformer at high-SNR peaks with matched
  (t,f,aperture); V magnitudes need matched apertures (bipolar/sidelobe fields fool
  whole-image sums and single pixels). Beam scalar corrections are positive-real and
  cannot flip signs — sign errors come from pol routing/convention, never the beam.
