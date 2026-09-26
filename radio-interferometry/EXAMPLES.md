# Examples (copy-paste, adjust paths)

## Inspect one MS

```bash
python - <<'PY'
from casacore.tables import table
t = table('x.ms', readonly=True, ack=False)
print(t.nrows(), t.colnames())
print('CORR_TYPE:', table('x.ms/POLARIZATION', ack=False).getcol('CORR_TYPE')[0])
PY
```

## Reorder pol axis to standard (if needed)

```bash
python scripts/reorder_ms_pol.py --src-dir ms/ --dst-dir ms_std/
```

## Bandpass + flag one MS (DP3)

```bash
DP3 msin=x.ms msin.datacolumn=DATA msout=. msout.datacolumn=CORRECTED_DATA \
 steps=[ac] ac.type=applycal ac.parmdb=cal.h5 ac.solset=sol000 \
 ac.steps=[amp,phase] ac.amp.correction=amplitude000 ac.phase.correction=phase000
DP3 msin=x.ms msin.datacolumn=CORRECTED_DATA msout=. msout.datacolumn=CORRECTED_DATA \
 steps=[aoflag] aoflag.type=aoflagger aoflag.strategy=strategy.lua aoflag.keepstatistics=false
```

## Full-sky model + bright-source subtraction

```bash
wsclean -j 8 -mem 6 -mgain 0.9 -niter 800 -weight uniform -horizon-mask 0.1deg \
 -pol I -size 3888 3888 -scale 2.84arcmin -data-column CORRECTED_DATA \
 -auto-mask 8 -auto-threshold 3 -field all -intervals-out 1 -minuv-l 10 \
 -no-reorder -no-dirty -no-update-model-required -quiet -no-negative \
 -save-source-list -name fullsky x.ms [y.ms ...]
# mask far-from-target components to far.txt (Sun example: exclude <6 deg), then:
DP3 msin=x.ms msin.datacolumn=CORRECTED_DATA msout=x_bsr.ms msout.datacolumn=DATA \
 msout.overwrite=true steps=[predict] predict.type=predict \
 predict.sourcedb=far.txt predict.operation=subtract
```

## Phase selfcal transfer + recenter + image

```bash
DP3 msin=x_bsr.ms msin.datacolumn=DATA msout=. msout.datacolumn=DATA \
 steps=[applycal] applycal.type=applycal applycal.parmdb=selfcal.h5 \
 applycal.steps=[phase] applycal.phase.correction=phase000
chgcentre x_bsr_sun.ms 21:32:34.655 +14.34.35.749
wsclean -j 8 -mem 6 -mgain 0.8 -niter 10000 -weight briggs -0.5 -horizon-mask 5deg \
 -pol I,V -size 384 384 -scale 1.8arcmin -data-column DATA -auto-threshold 3 \
 -minuv-l 10 -no-reorder -no-dirty -no-update-model-required -quiet \
 -join-polarizations -name img x_bsr_sun.ms
# spectral: add -channels-out 42 (per single-band MS for clean channel alignment)
```

## Flux spectrum → dynamic spectrum (from image tree)

```bash
# per image: flux[Jy] = sum(pixels)/beam_area_pixels  (beam from BMAJ/BMIN/CDELT)
# save NPZ(time, freq, flux_I/V, peak, rms) then pivot to [ntime, nfreq] and pcolormesh
# V/I with I-mask, average 2x2 if noisy; compare signs only at high SNR with matched apertures
```

## Big batch (188 timestamps, resumable)

```bash
bash scripts/batch_template.sh   # see scripts/: .done sentinels + manifest TSV + trap + per-unit work dirs cleaned on success
# tmux new-session -d -s run 'bash scripts/batch_template.sh'
```
