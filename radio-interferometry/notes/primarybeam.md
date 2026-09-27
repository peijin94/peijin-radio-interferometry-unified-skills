# Primary beam notes

## Role

Two separate jobs, often conflated:

1. **Jy/beam → Kelvin**: uses the synthesized beam solid angle
   (`1.222e6 / (BMAJ·BMIN·freq_GHz²)` from image header). Exact, per image. Needs
   valid BMAJ/BMIN/CRVAL3 or it silently skips — always verify BUNIT=K after.
2. **Beam attenuation correction**: divide by the primary-beam gain toward the target
   (0–1, <1 off-zenith). Requires a beam *model* evaluated at (freq, az, el).

## Memo178 (LWA operational default)

- Model class for the LWA station beam; used as `usebeam="Memo178Beam"` in the
  helio postprocess (`fitsj2000tohelio(..., beam_correction=True)`).
- Applied as a SINGLE scalar (gain at the target azimuth/elevation, CRVAL3 freq),
  recorded as PBGAIN/SUN_AZ/EL/PBMODEL. Appropriate for phase-centered solar work;
  wrong for off-axis sources (they need their own direction's gain).
- Gains are positive-real: beam division can scale flux but **cannot flip signs**
  (rules it out for any V-sign discrepancy by construction). It is also absent from
  raw/J2000 imaging paths (helio-only), so exclude it when diagnosing uncorrected data.

## Verifying correct use

- Confirm it ran: PBGAIN/PBMODEL header keys present, BUNIT=K, values changed by ~1/gain.
- Sanity: gain 0–1, decreasing away from zenith / with lower elevation; typical ~0.4–0.5
  for Sun at ~35–40° elevation near 80 MHz. Larger corrections amplify noise — watch
  background RMS after correction.
- Absolute accuracy is model uncertainty (affects flux scale, not signs or morphology).
  For precision off-axis work use direction-dependent methods (peeling/A-projection),
  not the scalar correction. Holography-measured beams beat analytic memos when available.
