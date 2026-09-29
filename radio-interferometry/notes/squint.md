# Beam squint → bipolar polarization artifacts: diagnose, plan, thoughts

## What it is

X and Y feeds never share identical beams (feed offsets, dish asymmetry, and for
dipole arrays, mutual coupling). Off-axis, X and Y see different gains, so
unpolarized sources acquire spurious polarization with a characteristic
bipolar/quadrupolar (+/−) pattern around the source. Fixed in the antenna (az–el)
frame, so it rotates on the sky with parallactic angle; grows with off-axis angle
and varies with frequency. On-axis (phase center) it is ~zero.

## Why it mimics real V (and how to tell)

- At unpolarized bright sources (Cas A/Cyg A), any V must be instrumental. Bipolar
  V there with |V|/I of a few % that is CONSTANT in time (beam fixed, source fixed)
  = squint/leakage floor. V that SCALES with another source's flux (e.g. stronger
  when the Sun bursts while A-Team flux is constant) = sidelobes of that source,
  not local squint. Use this time-scaling test to separate the two.
- Global D-terms (direction-independent leakage) cannot fix squint (it is
  direction-dependent); a D-terms null result does not rule squint in or out.
- Parallactic angle cannot create V (circular is rotation-invariant; PA only mixes
  Q↔U), and over seconds ΔPA≈0. To prove squint, compare V morphology around a
  bright source at widely separated PAs (hours apart): antenna-fixed squint rotates
  with PA on the sky; intrinsic sky polarization stays put.

## Plan to calibrate it

1. **Peeling / DD solves (no archives needed).** Per bright off-axis source: rotate
   phase center to it, average modestly, solve diagonal (or full-Jones) gains vs a
   point model, predict corrupted model, subtract, rotate back. Removes the source
   AND its squint sidelobes locally. Works per-observation from in-beam data.
2. **Full-Mueller A-projection** (gold standard): grid with per-pol, per-direction
   beam kernels. Needs full-Jones beam models for all antennas/freqs (usually not
   on hand) + heavy compute. Note: diagonal-only IDG and scalar beam division do
   NOT correct cross-pol squint.
3. **Holography-measured beams** (most accurate): map real per-antenna beams
   (incl. polarization) via dedicated scans, feed into (2). Needs observing time.
4. **Empirical squint mapping** (needs archives): unpolarized calibrators across many
   PAs/times (squint fixed in az–el, sky rotates) to fit the spurious-pol pattern.
5. **Avoidance:** keep the science target phase-centered (squint≈0 on-axis); only the
   off-axis subtraction quality suffers, via sidelobes leaking into the field.

## Thoughts for solar work

- The Sun (centered) is minimally affected; off-axis A-Team sidelobes leaking into
  the solar field are the practical damage — hence subtract A-Team well (DD-peel if
  sidelobes limit you; direction-independent subtraction leaves squint residuals).
- Our measured case: static ±1.7 Jy/bm floor at A-Team (squint/leakage) + Sun-driven
  variable component to ±5.6 Jy/bm (burst sidelobes). Fix the latter by removing the
  Sun model (peel/subtract burst); fix the former only via direction-dependent work.
- V magnitude gaps (2–3×) are dominated by X/Y amp, beam-pol, and clean — not squint
  (few-% effect). Don't chase squint for flux scale; chase it for sidelobe/background.
- U→V (X–Y phase) is unmeasurable from broken Q/U images: joint-clean Q/U
  overfit to checkerboards, so no X–Y phase can be inferred from them. Use a
  visibility D-term solve or an independently good U map instead.
- D-apply null, quantified: flagging 50 SNR-0 antennas and applying D-terms made
  V background worse (std 0.056→0.083, flagging loss + noisy D) while Cas A/Cyg A
  V/I stayed 4.7→4.8% / 3.8→3.6% (morphology pixel-identical). Few-% D-terms do
  not drive V; do not apply them operationally at this cost.
