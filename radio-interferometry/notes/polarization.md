# Polarization conventions and rules

## Beamformer V convention

The LWA beamformer (trigger spectra) uses V = Im(YX), which is IAU-correct
for linear feeds. Our imaging chain must reproduce this sign: bcal preserves
it (verified by null-YY swap test — parallels follow, no X/Y swap), Memo178
scalar beam division is positive-real (cannot flip sign), so any measured
flip is a real convention error (e.g. misordered pols), never the beam.

## Never pol-average gain solves

Always solve XX and YY separately (diagonal / diagonalphase). A pol-averaged
(T) solution forces X and Y to share one gain and corrupts their differences
— which is exactly what Stokes V measures. Measured residual X−Y phase after
proper diagonal cal is small (std 0.15 rad, 2.3% of antennas >0.2 rad), but
only because the solves were kept separate.

## Diagonal cal DOES fix X–Y phase/delay

Per-pol complex gains correct the relative X/Y phase and delay (plus slow
transfer re-corrects contemporaneously). What diagonal-only calibration does
NOT fix: cross-hand XY/YX gains, leakage D-terms (off-diagonal Jones), and
beam polarization (Mueller). Do not invoke "X–Y delay" for V problems that
survive diagonal cal — look at X/Y amplitude, beam pol, and clean bias.

## RR/LL from linear data

Circular basis from Stokes images: RR = (I+V)/2, LL = (I−V)/2. Fit/track
RR and LL centroids separately; a genuine polarized source shows
RR/LL offsets (we measured ~13″ in x at burst peak), while identical RR/LL
tracks flag a calibration or fitting artifact.

## V magnitude gap decomposition

When interferometric |V| runs ~2–3× below beamformer V at matched (t,f):
drivers are X/Y amplitude imbalance, beam polarization, and clean/aperture
bias (bipolar cancellation under the beam). Ruled out as primary causes:
X–Y delay (fixed by diagonal cal), leakage/D-terms (few-% effect;
D-apply left Cas A/Cyg A V/I unchanged), and noise (peaks are high-SNR).
Full-Jones/polcal is still needed for precision V magnitudes; signs are
unaffected either way.
