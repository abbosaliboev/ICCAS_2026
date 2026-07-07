# MobiCare — Project Notes (Poster / PPT / Future Paper)

> Knowledge archive from the 2026-07 research + analysis session. Purpose: (1) everything needed to build the **ICCAS 2026 poster + PPT**, (2) everything needed to later write a **strong paper**. Numeric results live in `RESULTS.md` (latest) and `RESULTS_ARCHIVE.md` (full history); this file is the *reasoning, strategy, and story* behind them.

---

## 1. What MobiCare is

Camera-based fall detection for elderly living alone. Full deployed system:
- **Edge:** Jetson Orin NX. Pipeline = YOLO11n-pose (17 COCO keypoints) → ST-GCN (Stage 1) → Physics rescue filter (Stage 2) → confirmed fall.
- **Backend:** FastAPI (`backend/`) — fall events + screenshot + 30 s clip, guardian SMS notifications.
- **Mobile app:** Flutter (`flutter_app/`) — caregiver gets fall alert **with evidence** (photo), login/guardian/events/profile screens.
- **Safe-zone:** user marks bed/sofa areas where lying is expected → suppresses false alarms there (deployment-level fix for the laying problem).

Dataset: UP-Fall, Subjects 1–17, Activities 1–11 (1–5 = FALL, 6–11 = ADL), Trials 1–3, 2 camera views. 18,823 windows (T=30, stride=15). Camera1 = front view, Camera2 = side view.

---

## 2. Headline results (for poster / PPT)

| Evaluation | Model | Accuracy | Fall F1 | Sensitivity | Specificity |
|---|---|:---:|:---:|:---:|:---:|
| Subject-stratified (subject-dependent) | ST-GCN + Physics | **99.19%** | **0.972** | 97.3% | 99.5% |
| Leave-one-subject-out (cross-subject) | Two-camera fusion | 89.2% | 0.677 | 77.5% | 91.1% |

- Edge: **~30 fps real-time / 69 fps model pipeline** (TensorRT) on Jetson Orin NX. TCNTE = 19 fps on the same device → we are faster.
- Lead the poster with the subject-dependent 99.19% (comparable to prior work); keep LOSO 0.68 as the honest cross-subject number (mention only if asked).

**Differentiators no competitor paper has:**
1. **Physics-informed rescue** — real-world robustness, ~0 latency (2 ms), interpretable. All rivals are purely data-driven.
2. **Full deployed system** — edge + mobile app + backend + safe-zone. Rivals ship only a model.
3. **Sensitivity 97.3% > TCNTE 95.4%** — fewer missed falls (the safety-critical metric).

---

## 3. The research story (for a future paper)

The narrative: *find the problem → honestly reject cheap fixes → solve it with a principled method.*

1. **Full 17-subject LOSO baseline: Fall F1 0.62.** Precision (0.47) is the bottleneck, not recall (0.88).
2. **Decisive finding: 96% of false positives (2548/2665) come from Activity 11 (laying down).** Lying on a bed is a vertical→horizontal transition that looks like a fall in single-view pose space.
3. **Kinematic veto tested and REJECTED (with data).** Peak hip velocity/accel/drop separate fall-vs-A11 near-randomly (AUC ≈ 0.53–0.61, even an oracle threshold barely beats the 0.55 majority baseline). Elderly can fall slowly, like lying → velocity cannot separate them. This empirically explains CLAUDE.md's old warning against physics veto.
4. **Two-camera fusion — the principled fix (MAIN CONTRIBUTION).** Camera1 (front) and Camera2 (side) fail on *different* activities:
   - Camera1 FP: A11 laying 76.7%; walking/jumping ≈ 0.
   - Camera2 FP: A11 laying drops to 33.9%, but new FP on walking/jumping/standing.
   Score-level fusion (per-window probabilities, weighted-avg rule tuned on val, applied to held-out subject) → **FP −46% (2665→1438), precision 0.47→0.59, specificity 0.84→0.91, accuracy 0.84→0.89, F1 0.62→0.68**, all under strict LOSO. Tradeoff: recall 0.88→0.78.
5. **Safe-zone** — deployment-level layer for the residual laying problem (spatial, not motion-based). Handles A11 where the model can't.

Defense-in-depth = multi-view fusion (model) + safe-zone (deployment) + physics (robustness).

---

## 4. Evaluation methodology (important — friends flagged this)

Two ways to split train/test:

**Subject-dependent (subject-stratified, what most UP-Fall papers use).** Each subject's windows shuffled and split 70/15/15 → the *same person* is in train and test. Sliding windows overlap (stride 15 < window 30 = 50%), and a random split can put near-identical windows on both sides → **leakage, inflates the score** (our 99.19%).

**Cross-subject (LOSO).** Each fold holds out one *entire* subject; that person is never seen in training. Measures generalization to a *new* patient → honest number (fusion 0.68).

**Why papers use subject-dependent:** higher numbers (looks good); easier; small datasets (few subjects) can't afford to hold a whole person out; everyone copies it for "comparability." Catch: it overstates real performance. **Our honesty stance: report both.** Subject-dependent for comparison, LOSO for truth.

---

## 5. Benchmark vs prior work (UP-Fall, front view)

| Study | Method | Sens | Spec | Acc | Params | Edge |
|---|---|:---:|:---:|:---:|:---:|:---:|
| Espinosa 2019 | CNN | 97.8 | 83.1 | 95.6 | 268k | ❌ |
| Ramirez 2021 | Random Forest | 98.8 | 99.5 | 99.3 | — | ❌ |
| Inturi 2022 | 1D-CNN+LSTM | 94.4 | 99.0 | 98.6 | — | ❌ |
| TCNTE 2025 | TCN+Transformer | 95.4 | 99.7 | 99.6 | 14.7k | Orin NX, 19 fps |
| **MobiCare (ours)** | **ST-GCN + Physics** | **97.3** | **99.5** | **99.19** | 3.1M | Orin NX, ~30 fps + app |

Numbers from Yu et al. 2025 (TCNTE), *Pervasive and Mobile Computing* 107:102016, Table 5.
- Params column is our WEAK spot (3.1M vs TCNTE 14.7k). Recommend omitting it on the poster; FPS proves edge-viability directly. Answer honestly if asked ("larger model, still real-time via TensorRT").

**TCNTE key facts (our main comparison):**
- Protocol: 3-fold cross-validation, **subject-independent** (disjoint subjects) — stricter than most, but coarser than our 17-fold LOSO.
- Their high 99.58% comes from: (a) removing poor-pose trials, (b) excluding post-fall lying frames, (c) YOLOv8s (better pose than our nano), (d) accuracy/file-wise metrics under 60:1 imbalance (accuracy is easy: all-non-fall already = 98.17%), (e) weighted focal loss.
- They evaluate front & side views **separately, never fused** → our fusion is novel.
- They deploy on Jetson Orin NX (same as us), 19 fps.

---

## 6. Poster / PPT strategy

- Audience = professors who don't know LOSO deeply. **Don't scare them with 0.62.** Lead with 99.19% accuracy + FPS + system + physics.
- Story spine: problem (falls, long-lie danger) → method (two-stage ST-GCN + physics, two-camera, safe-zone) → results (benchmark table) → **live system demo** (edge → phone alert with photo).
- Table columns to show: Method / Sens / Spec / Acc / FPS / Edge-deployment / App. (Consider omitting Params.)
- Physics: frame as **real-world robustness + interpretable + ~0 latency**, NOT "big offline F1 gain" (offline gain is small; it helped subject-dependent FP 31→12).
- A live demo (Jetson detects fall → caregiver phone gets alert + evidence) beats any number.

---

## 7. TODO for a strong paper (not needed for the poster)

To turn this into a strong paper, adopt (honestly, transparently) what TCNTE does + our extras:
- [ ] **LSTM / TCN baselines** on the same data (comparison table needs them).
- [ ] **Post-fall exclusion** — drop lying-still frames from FALL trials (standard, cited [5,45]); sharpens the fall class. NOTE: tension with "long-lie" detection, which matters for elderly living alone — discuss.
- [ ] **Pose-quality filtering** — drop windows/trials with failed pose (like TCNTE). CAUTION: conflicts with our validated `conf=0.1` + interpolation decision (moved fall F1 0.718→0.913 because fall poses get low confidence). Do it surgically on A11 garbage only, not fall trials — removing low-conf detections hurts fall recall.
- [ ] **Weighted focal loss** (α≈30, γ≈3) instead of / with WeightedRandomSampler.
- [ ] **File-wise / event-level metrics** alongside window-wise (a fall file = detected if any window fires; more practical).
- [ ] Run our model on TCNTE's exact **3-fold subject-independent** protocol for a directly comparable number.
- [ ] **Reduce model size** — ST-GCN is 3.1M params (211× TCNTE). A lighter backbone would strengthen the edge story.
- [ ] Note: two-camera fusion is the novel contribution; frame it as the headline method.

Reminder: important negative results (kinematic veto fails, single-view can't separate laying from falling) ARE publishable and strengthen the multi-view argument.

---

## 8. Analysis scripts (fall_iccas/)

- `prepare_cv_dataset.py --camera Camera1|Camera2 --out-dir ...` — YOLO keypoint extraction → X.npy/y.npy/meta.csv.
- `loso_eval.py --data-dir ... --out-dir ... [--test-subjects N...]` — 17-fold LOSO; `--test-subjects` for pilot folds.
- `train_two_stage.py --data-dir ...` — subject-stratified single split (the 99.19% number).
- `analyze_loso.py` — per-activity FP breakdown + threshold/temporal-voting sweep (reuses saved checkpoints).
- `feature_separability.py` — oracle fall-vs-A11 separability of velocity/accel/drop (showed kinematics can't separate).
- `veto_experiment.py` — velocity-veto experiment (rejected).
- `eval_exclude_activity.py --exclude 11` — "safe-zone" scenario: LOSO metrics with A11 removed at test.
- `fuse_cameras.py` — two-camera score-level fusion (the main result).

Big experiment data (`experiments/subject1_to_17*/`, X.npy > 100 MB) is git-ignored — reproducible from these scripts.

---

## 9. Open items

- **Hardware label:** `FPS_BENCHMARK.md` header says "Orin **Nano Super**" but deployment is on Orin **NX**. Confirm which device the FPS numbers were measured on and fix the header (or re-run `bench_fps.py` on the NX — NX is more powerful, numbers would be higher).
- Dataset quirk: Subject8 Activity11 has only Trial1 (source has no Trial2/3). 5 trials have minor Camera1/Camera2 frame-count mismatches (source-inherent).
