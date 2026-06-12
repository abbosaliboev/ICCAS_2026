# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

MobiCare — an ICCAS 2026 paper project for camera-based fall detection of elderly people living alone. Pure Python research code (PyTorch + Ultralytics YOLO); there is no build system, test suite, linter, or requirements file. Dependencies used across scripts: `torch`, `ultralytics`, `opencv-python`, `scipy`, `scikit-learn`, `pandas`, `numpy`, `matplotlib`.

Documentation is multilingual: root `README.md` is English/Korean, `fall_iccas/*.md` docs have English/Korean/Uzbek sections (keep all three in sync when editing them), and code comments mix Korean/English.

## Two codebases

- **`fall_iccas/`** — the main, current work: two-stage fall detector (ST-GCN + physics rescue filter) trained on the UP-Fall dataset. See `fall_iccas/ARCHITECTURE.md` for the full design and `fall_iccas/RESULTS.md` for the run history.
- **`yolowithfilter/`** — earlier prototype: YOLO11n-pose → hip-Y CSV → pixel-to-meter scale estimation → Butterworth-filtered velocity/acceleration thresholds. `vel_acc_calculation_pipeline.py` chains `detection_dataset.py` → `scale_discover.py` → `filter.py` via subprocess.

## Commands (fall_iccas)

Run from inside `fall_iccas/`:

```bash
python prepare_cv_dataset.py   # YOLO keypoint extraction → cv_dataset/{X.npy, y.npy, meta.csv}
python train_two_stage.py      # full pipeline: split → train ST-GCN → fit physics thresholds → evaluate
```

`prepare_cv_dataset.py` expects raw UP-Fall images at `fall_iccas/dataset/SubjectN/ActivityN/TrialN/Camera1/` — this directory is not committed; the extracted `cv_dataset/` arrays are. Training saves `checkpoints/best_stgcn.pth` (selected by val fall-F1) and `checkpoints/two_stage_config.json` (tuned thresholds). `train_stgcn.py` is the older Stage-1-only trainer.

## Architecture (the part that spans files)

Pipeline: camera frames → YOLO11n-pose (17 COCO keypoints, normalized to [0,1]) → zero-frame forward/backward fill → sliding window (T=30, stride=15, ~19 FPS) → ST-GCN → threshold logic.

Data shape contract: `X.npy` is `(N, 30, 17, 3)` with channels (x, y, conf); `FallDataset` in `train_two_stage.py` transposes to `(C, T, V, M=1)` for the model. Labels: UP-Fall activities 1–5 = FALL, 6–11 = NO-FALL.

`stgcn/` package:
- `graph.py` — COCO 17-joint adjacency matrix `(3, 17, 17)` (self/centripetal/centrifugal subsets, center node = left hip)
- `model.py` — 9-block ST-GCN with learnable attention mask
- `physics.py` — `PhysicsFilter`: Butterworth low-pass on mid-hip Y, velocity/acceleration features, grid-searched thresholds
- `two_stage.py` — `TwoStageDetector` with **Rescue logic**: `p ≥ 0.55 → FALL`, `0.50 ≤ p < 0.55 → physics decides`, `p < 0.50 → NO-FALL`

The Rescue design is deliberate and hard-won: an earlier `Stage1 AND physics` combination *hurt* F1 (0.913 → 0.864) because physics vetoed correct ST-GCN detections. Physics may only add falls in the uncertain zone, never remove Stage-1 positives. Don't reintroduce AND-style gating.

Other settled decisions (see `RESULTS.md` for evidence):
- YOLO `conf=0.1` (unusually low) plus zero-frame interpolation is intentional — fall poses get low confidence, and this fix moved fall F1 from 0.718 to 0.913. Don't raise the threshold to a "normal" value.
- Current results (F1 0.96) are Subject-1-only, subject-dependent. The paper needs LOSO (leave-one-subject-out) evaluation across Subjects 1–17 and LSTM/TCN baselines — both still TODO.

## Conventions

- After meaningful training runs, append the results to `fall_iccas/RESULTS.md` (it is a dated run history with config + confusion matrix).
- Config lives as module-level constants at the top of each script (no argparse/config files); tuned thresholds are persisted to `checkpoints/two_stage_config.json`.
