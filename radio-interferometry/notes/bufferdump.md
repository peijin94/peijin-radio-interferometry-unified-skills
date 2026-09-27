# Buffer-dump Measurement Sets (fast triggered data)

## What they are

Correlator dumps of triggered fast recordings: one short integration per file
(e.g. 8 ms), full array (e.g. 352 antennas → 62128 baselines incl. autos), split into
sub-bands (e.g. `high` 83 ch and `low` 84 ch at ~12 kHz covering ~79–81 MHz).
Filenames encode time to the millisecond (`...T205818p473.ms`, `pNNN` = ms).
Phase center often zenith; one field; single time sample per file.

## How they differ from standard data

| | slow standard | fast standard | buffer dump |
|---|---|---|---|
| cadence | ~10 s | ~0.1 s | ~8 ms (one int/file) |
| channels | 192 @ ~24 kHz | 48 @ ~96 kHz, 48 ants | ~83 @ ~12 kHz, full array |
| span/file | one 10 s frame | 100 samples / 10 s | one dump |
| use | reference calibration | high-rate context | burst science |

## Handling rules

1. **Copy, never touch raws.** Work on copies; originals stay pristine.
2. **Check pol order FIRST** (`CORR_TYPE` vs Stokes.h: 9–12 are linear XX/XY/YX/YY).
   Reorder once to standard `[XX,XY,YX,YY]` before any WSClean work; validate with
   reordered-vs-original dirty images (must correlate +1.0).
3. **Expect a different path gain** than standard data (raw counts can differ by ~1e2;
   verify via ratios, don't assume). Bandpass from the covering standard band works
   for shape; confirm scale against a reference.
4. **Stack for SNR.** Single dumps are sidelobe-dominated (no Earth rotation in ms);
   ~0.1–1 s units image cleanly after bright-source removal. More time helps noise,
   not UV filling.
5. **Subtract bright sources always** (A-Team + full-sky model); snapshots drown in
   their sidelobes otherwise. Unpolarized-model subtraction does not touch V
   cross-hands — budget separate V work (models/leakage).
6. **Transfer, don't solve, phases** (single-dump solves return zeros/garbage;
   stacked short-chunk solves stay marginal; stable reference solutions win).
7. **Validate V sign/scale vs beamformer** at high-SNR peaks with matched (t,f,
   aperture); whole-image sums and single pixels mislead on bipolar/sidelobe fields.
8. **Batch everything** (hundreds of files): resumable drivers, manifests, clean work
   dirs on success, `ulimit -n 65536`, niced threads, tmux + logs.
