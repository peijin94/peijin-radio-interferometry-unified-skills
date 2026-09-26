# radio-interferometry — detailed reference

Conventions: `$MS` = input Measurement Set, `$WORK` = scratch work dir (never write
raws), DP3 = `/opt/dp3-*.x/bin/DP3` (adjust path), WSClean ≥3, CASA 6 (casatasks /
python-casacore). LWA notes inline where relevant.

## 1. Environment and layout

```bash
source <env>  # must provide: python + casatools + python-casacore + DP3 + wsclean + chgcentre
mkdir -p proc/{work,logs} out bcal gcal imgs
```

Keep raw MS read-only. Copy inputs to work dirs; write products to new MS/FITS.
Run long jobs in tmux, niced (`nice -n 19 ionice -c3`), one heavy job at a time
unless memory clearly allows parallel (full-sky images OOM in parallel).

## 2. Inspect data (do this first, always)

```python
from casacore.tables import table
t = table('x.ms', readonly=True, ack=False)
print(t.nrows(), t.colnames())  # expect DATA (+FLAG); note CORRECTED_DATA/MODEL_DATA presence
tt = t.getcol('TIME'); print('times:', tt.min(), tt.max(), 'dt:', tt[1]-tt[0])
for sub in ('SPECTRAL_WINDOW','POLARIZATION','FIELD','OBSERVATION','ANTENNA'):
    s = table(f'x.ms/{sub}', ack=False)
    if sub=='SPECTRAL_WINDOW':
        f=s.getcol('CHAN_FREQ')[0]; print(f"nchan={len(f)} {f[0]/1e6:.3f}-{f[-1]/1e6:.3f} MHz")
    if sub=='POLARIZATION':
        print('CORR_TYPE:', s.getcol('CORR_TYPE')[0], '(want [5,6,7,8] or [9,10,11,12] in standard order)')
    s.close()
t.close()
```

CASA Stokes codes: I=1 Q=2 U=3 V=4 RR=5 RL=6 LR=7 LL=8 **XX=9 XY=10 YX=11 YY=12**
(linear, not circular — verify in `casacore/measures/Measures/Stokes.h`).
Standard linear order is `[XX,XY,YX,YY]` = `[9,10,11,12]`. Feeds are usually `[X,Y]`.

## 3. Normalize polarization order (do before any WSClean work)

WSClean (predict, and gridding per tests) assumes standard order by index and
ignores non-standard `CORR_TYPE` — scrambling Q/U/V and halving I. If order is not
standard, permute once to `[XX,XY,YX,YY]` and relabel (script in `scripts/`):

```python
perm = [0,2,3,1]  # example: [XX,YY,XY,YX] -> [XX,XY,YX,YY]
# for each array col with pol axis (DATA, FLAG, WEIGHT_SPECTRUM, CORRECTED_DATA...):
t.putcol(col, arr[:,:,perm])
# POLARIZATION: CORR_TYPE=[9,10,11,12], CORR_PRODUCT=[[0,0],[0,1],[1,0],[1,1]]
```

Validate with dirty images reordered-vs-original (must correlate +1.0) and by
checking a Stokes-V predict lands in cross-hands (indices 2,3), parallels ~0.

## 4. Bandpass (primary calibration)

DP3 `applycal` of the nearest-band primary table (must span your frequencies):

```bash
DP3 verbosity=quiet msin=$MS msin.datacolumn=DATA msout=. msout.datacolumn=CORRECTED_DATA \
 steps=[ac] ac.type=applycal ac.parmdb=$CALTABLE ac.solset=sol000 \
 ac.steps=[amp,phase] ac.amp.correction=amplitude000 ac.phase.correction=phase000 \
 ac.amp.interpolation=linear ac.phase.interpolation=linear
```

Caltable pols are usually `[XX,YY]` only. Verify mapping (null one pol in a test copy;
parallel hands must follow, no X/Y swap) when V sign matters. Confirm in/out amplitude
ratio matches expectation for your path (compare to a reference dataset if the path is
new — e.g. buffer vs standard can differ by ~1e2 in raw counts).

## 5. Flag

DP3 AOFlagger on `CORRECTED_DATA` in place (strategy e.g. `LWA_sun_PZ.lua`,
`aoflag.keepstatistics=false`). Cheap; keeps RFI out of models. Verify flag fraction
per baseline-length bin (overflagging short baselines kills solar flux).

## 6. Selfcalibration

Prefer **transferred** solutions from a stable reference (long integrations, high SNR):
DP3 `applycal` of a phase (or amp+phase) H5Parm. Validate by imaging improvement
(background RMS down, peak up/coherent), not just solution stats.

Solve fresh ONLY on stacked high-SNR data (concatenated chunks, never single
snapshots — solvers return zeros/garbage/nondeterministic phases on sparse data):

```bash
# 1) model image (full-sky or FOV) with WSClean on calibrated data
# 2) WSClean -predict <model-prefix> <ms>   # materializes MODEL_DATA
#    (DP3 predict does NOT flush MODEL_DATA; do not rely on it)
# 3) DP3 gaincal diagonalphase, solint=0, uvlambdamin~30, usemodelcolumn=true
# 4) validate h5: finite>50%, phase std<0.6 rad (reject otherwise), stable across reruns
# 5) DP3 applycal phase000
```

For polarization (cross-hands/leakage): diagonal solves never touch XY/YX. Use CASA
`polcal` (Df/D, Xf) on long baselines with unpolarized calibrators (Cas A/Cyg A),
or DP3 `fulljones` with a full-Stokes model. Validate by V on unpolarized sources
decreasing (typical good leakage is a few %); do not expect it to fix large (>2x)
amplitude scale gaps (those are X/Y amp, beam, or clean — separate issues).

## 7. Bright-source removal

```bash
# model (WSClean full-sky/FOV, -save-source-list) -> mask far-from-target -> subtract
DP3 msin=$MS msin.datacolumn=CORRECTED_DATA msout=$OUT.ms msout.datacolumn=DATA \
 msout.overwrite=true steps=[predict] predict.type=predict \
 predict.sourcedb=$FARLIST predict.operation=subtract
```

Notes: new-MS outputs can only write `DATA`; protect the target (exclude near-Sun
components, e.g. >6 deg); A-Team (Cas A/Cyg A, unpolarized) anchor both astrometry
(positions to <0.05 deg) and flux scale; subtracting I models does not touch V
cross-hands (V artifacts need V models/leakage work, not I subtraction).

## 8. Phase center and imaging

`chgcentre <ms> <RA_h:m:s> <Dec.d.m.s>` (Dec needs `.` separators) to the target,
then WSClean. WSClean accepts multiple MS (same phase center). Typical solar:
`-size 384 384 -scale 1.8arcmin -weight briggs -0.5 -pol I,V -niter 10000 -mgain 0.8
-auto-threshold 3 -minuv-l 10 -join-polarizations`. Spectral: `-channels-out N`
(per-stream for multi-band MS to keep channel alignment; note it also writes MFS).
Small-FOV snapshots need stacked time (single 8 ms dumps are sidelobe-dominated;
~0.1–1 s units work after bright-source removal). Keep model/residual/psf.

## 9. Postprocess and spectra

Helioprojective + Kelvin + beam (pipeline `fitsj2000tohelio`-style: rotate by solar P,
J2000→HPLN/HPLT arcsec, Jy/beam→K via beam solid angle, divide by scalar beam gain
toward target). Note: scalar beam gains are positive-real (cannot flip V sign) and
correct only the phase-center direction. Integrated spectra: flux[Jy] =
sum(pixels)/beam_area_pixels per (time,freq) image → NPZ(time,freq,flux,peak,rms) →
dynamic spectrum (time×freq), light curves, slices. Mask low-I pixels for V/I.

## 10. Batch runs (big jobs)

One unit at a time (or few if memory allows), `nice/ionice`, tmux + log file +
manifest TSV + `.done` sentinels, `trap` on INT/TERM, skip-if-done resume, clean
work dirs on success (keep failures), `ulimit -n 65536` when opening hundreds of MS
(too-many-open-files otherwise). Template: `scripts/batch_template.sh`.

## 11. Validation gates (run these, in order)

1. Bandpass parity: in/out ratio matches reference path; no X/Y swap (null-pol test).
2. Pol order: reordered-vs-original dirty images correlate +1.0; V predict lands in
   cross-hands.
3. Astrometry: A-Team within ~0.05 deg of catalog; Sun at expected helio offset.
4. Flux scale: A-Team totals vs beam-corrected models (order unity after path gain).
5. V sign: high-SNR burst peaks vs beamformer (must match); use matched apertures —
   whole-image sums and single pixels mislead on bipolar/sidelobe fields.
6. Quality: background RMS / dynamic range improves vs uncalibrated; residuals sane.
