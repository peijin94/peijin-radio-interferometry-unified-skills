#!/usr/bin/env python3
"""Reorder MS polarization axis to standard [XX,XY,YX,YY] (CASA 9,10,11,12).

Buffer MS use non-standard [XX,YY,XY,YX]. WSClean (at least predict, and
gridding per dirty-image test) does not fully honor CORR_TYPE, scrambling
Q/U/V and halving I. Reordering to standard once guarantees all downstream
tools see a canonical layout. Operates on copies; never touch originals.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

PERM = [0, 2, 3, 1]  # old [XX,YY,XY,YX] -> new [XX,XY,YX,YY]
NEW_TYPES = [9, 10, 11, 12]
NEW_PROD = [[0, 0], [0, 1], [1, 0], [1, 1]]


def reorder_one(src: Path, dst: Path) -> None:
    from casacore.tables import table
    import numpy as np
    import os

    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    with table(str(dst), readonly=False, ack=False) as t:
        n = t.nrows()
        for col in ("DATA", "FLAG", "WEIGHT_SPECTRUM", "CORRECTED_DATA", "MODEL_DATA"):
            if col not in t.colnames():
                continue
            v = np.asarray(t.getcol(col, startrow=0, nrow=n))
            if v.ndim == 3 and v.shape[2] == 4:
                t.putcol(col, v[:, :, PERM], startrow=0, nrow=n)
        pol = table(os.path.join(dst, "POLARIZATION"), readonly=False, ack=False)
        pol.putcol("CORR_TYPE", np.array([NEW_TYPES], dtype=np.int32))
        pol.putcol("CORR_PRODUCT", np.array([NEW_PROD], dtype=np.int32))
        pol.close()
    print(f"[reorder] {dst.name}", flush=True)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src-dir", type=Path, required=True)
    ap.add_argument("--dst-dir", type=Path, required=True)
    ap.add_argument("--pattern", default="ms_*.ms")
    ap.add_argument("--limit", type=int, default=None)
    args = ap.parse_args(argv)
    srcs = sorted(args.src_dir.expanduser().resolve().glob(args.pattern))
    if args.limit:
        srcs = srcs[: args.limit]
    dst = args.dst_dir.expanduser().resolve()
    dst.mkdir(parents=True, exist_ok=True)
    for s in srcs:
        reorder_one(s, dst / s.name)
    print(f"[reorder] done {len(srcs)} -> {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
