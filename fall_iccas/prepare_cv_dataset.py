"""
CV dataset preparation for TCN / ST-GCN fall detection.
Keypoint extractor: YOLOv11n-pose  (17 COCO joints)

Pipeline:
  images -> YOLO-pose -> 17 keypoints (x, y, conf) per frame
         -> sliding-window sequences
         -> X.npy  (N, T, V, C)   N sequences, T=30 frames, V=17 joints, C=3 (x,y,conf)
         -> y.npy  (N,)            0=no-fall  1=fall
         -> meta.csv

Normalized coords: x,y divided by image width/height -> [0,1]
Confidence from YOLO kept as 3rd channel.

ST-GCN: X.transpose(0,3,1,2)[:,None] -> (N, C, T, V, 1)
TCN   : X.reshape(N, T, -1)          -> (N, T, V*C)

Usage examples:
  python prepare_cv_dataset.py                          # all subjects -> cv_dataset/
  python prepare_cv_dataset.py --subjects 1 2           # Subject1+2 only
  python prepare_cv_dataset.py --subjects 1 2 --out-dir experiments/subject1_2/cv_dataset
"""

import os
import re
import csv
import argparse
import numpy as np
import cv2
from ultralytics import YOLO

# ── config ────────────────────────────────────────────────────────────────────
DATASET_DIR = os.path.join(os.path.dirname(__file__), "dataset")
CAMERA      = "Camera1"
WINDOW_SIZE = 30
STRIDE      = 15
FALL_ACTIVITIES = {1, 2, 3, 4, 5}
N_JOINTS    = 17
N_COORDS    = 3     # x, y, confidence

# load once
import torch
if torch.cuda.is_available():
    torch.cuda.init()
    torch.cuda.empty_cache()
    torch.backends.cuda.enable_flash_sdp(False)
    torch.backends.cuda.enable_mem_efficient_sdp(False)
    torch.backends.cuda.enable_math_sdp(True)
    DEVICE = "cuda"
else:
    DEVICE = "cpu"
MODEL = YOLO("yolo11n-pose.pt")
if DEVICE == "cuda":
    MODEL.to("cuda")   # move to GPU at load time, not lazily at first inference


def sorted_images(folder):
    exts = {".jpg", ".jpeg", ".png", ".bmp"}
    return sorted(f for f in os.listdir(folder)
                  if os.path.splitext(f)[1].lower() in exts)


def extract_keypoints_batch(img_paths, batch_size=16 if DEVICE == "cuda" else 1):
    """
    Run YOLO-pose on a list of images in batches.
    Returns (F, 17, 3) array — x, y normalized, confidence.
    Keypoints extracted immediately per batch to keep RAM usage minimal.
    """
    import gc
    kps = np.zeros((len(img_paths), N_JOINTS, N_COORDS), dtype=np.float32)

    for i in range(0, len(img_paths), batch_size):
        batch_paths = img_paths[i: i + batch_size]
        batch = [cv2.imread(p) for p in batch_paths]
        batch = [b if b is not None else np.zeros((480, 640, 3), dtype=np.uint8)
                 for b in batch]

        results = MODEL(batch, verbose=False, conf=0.1, device=DEVICE)

        for j, res in enumerate(results):
            idx = i + j
            if res.keypoints is None or len(res.keypoints.xy) == 0:
                continue
            person_idx = int(res.keypoints.conf.sum(dim=1).argmax()) \
                         if res.keypoints.conf is not None else 0
            xy   = res.keypoints.xy[person_idx].cpu().numpy()
            conf = res.keypoints.conf[person_idx].cpu().numpy()
            h, w = res.orig_shape
            kps[idx, :, 0] = xy[:, 0] / w
            kps[idx, :, 1] = xy[:, 1] / h
            kps[idx, :, 2] = conf

        del results, batch
        gc.collect()

    return kps   # (F, 17, 3)


def interpolate_zero_frames(kps: np.ndarray) -> np.ndarray:
    """
    Fill zero frames (failed detections) using forward-fill then backward-fill.
    A frame is zero when all xy coordinates sum to 0.
    kps : (F, 17, 3)
    """
    kps = kps.copy()
    F = len(kps)
    is_zero = kps[:, :, :2].sum(axis=(1, 2)) == 0  # (F,)

    if not is_zero.any():
        return kps

    # forward fill
    last_valid = None
    for i in range(F):
        if not is_zero[i]:
            last_valid = kps[i].copy()
        elif last_valid is not None:
            kps[i] = last_valid

    # backward fill for leading zeros
    first_valid = None
    for i in range(F):
        if kps[i, :, :2].sum() > 0:
            first_valid = kps[i].copy()
            break
    if first_valid is not None:
        for i in range(F):
            if kps[i, :, :2].sum() == 0:
                kps[i] = first_valid
            else:
                break

    return kps


def get_trials(root, subjects=None):
    """Yield (subj_id, act_id, trial_id, cam_folder, imgs).
    subjects: set of ints to include, or None for all.
    """
    for subj_name in sorted(os.listdir(root)):
        sm = re.match(r"Subject(\d+)$", subj_name)
        if not sm:
            continue
        subj_id = int(sm.group(1))
        if subjects is not None and subj_id not in subjects:
            continue
        subj_path = os.path.join(root, subj_name)

        for act_name in sorted(os.listdir(subj_path)):
            am = re.match(r"Activity(\d+)$", act_name)
            if not am:
                continue
            act_id = int(am.group(1))
            act_path = os.path.join(subj_path, act_name)

            for trial_name in sorted(os.listdir(act_path)):
                tm = re.match(r"Trial(\d+)$", trial_name)
                if not tm:
                    continue
                trial_id = int(tm.group(1))
                trial_path = os.path.join(act_path, trial_name)

                cam_folder = None
                for d in os.listdir(trial_path):
                    if CAMERA in d and os.path.isdir(os.path.join(trial_path, d)):
                        cam_folder = os.path.join(trial_path, d)
                        break
                if cam_folder is None:
                    continue

                imgs = sorted_images(cam_folder)
                if not imgs:
                    continue

                yield subj_id, act_id, trial_id, cam_folder, imgs


def main():
    parser = argparse.ArgumentParser(description="Extract YOLO keypoints into sliding-window arrays.")
    parser.add_argument("--subjects", type=int, nargs="+", default=None,
                        help="Subject IDs to include (e.g. 1 2). Default: all.")
    parser.add_argument("--out-dir", default=None,
                        help="Output directory for X.npy / y.npy / meta.csv. "
                             "Default: <script_dir>/cv_dataset")
    args = parser.parse_args()

    subjects = set(args.subjects) if args.subjects else None
    out_dir  = args.out_dir or os.path.join(os.path.dirname(__file__), "cv_dataset")
    os.makedirs(out_dir, exist_ok=True)

    subj_label = f"Subject{sorted(subjects)}" if subjects else "All subjects"
    print(f"Dataset dir : {DATASET_DIR}")
    print(f"Subjects    : {subj_label}")
    print(f"Output dir  : {out_dir}")
    print(f"Device      : {DEVICE}\n")


    import gc
    all_X, all_y, meta_rows = [], [], []
    seq_id = 0

    for subj_id, act_id, trial_id, cam_folder, imgs in get_trials(DATASET_DIR, subjects):
        label = 1 if act_id in FALL_ACTIVITIES else 0
        print(f"  S{subj_id} A{act_id} T{trial_id}  {len(imgs)} frames  label={label}")

        img_paths = [os.path.join(cam_folder, f) for f in imgs]
        trial_kps = extract_keypoints_batch(img_paths)  # (F, 17, 3)
        gc.collect()

        # fill failed detections from neighboring frames
        zeros_before = int((trial_kps[:, :, :2].sum(axis=(1, 2)) == 0).sum())
        trial_kps = interpolate_zero_frames(trial_kps)
        zeros_after = int((trial_kps[:, :, :2].sum(axis=(1, 2)) == 0).sum())
        if zeros_before > 0:
            print(f"    zero frames: {zeros_before} -> {zeros_after} after interpolation")

        F = len(trial_kps)
        if F < WINDOW_SIZE:
            pad = np.tile(trial_kps[-1:], (WINDOW_SIZE - F, 1, 1))
            trial_kps = np.concatenate([trial_kps, pad], axis=0)
            F = WINDOW_SIZE

        start = 0
        while start + WINDOW_SIZE <= F:
            window = trial_kps[start: start + WINDOW_SIZE]  # (T, V, C)
            all_X.append(window)
            all_y.append(label)
            meta_rows.append({
                "seq_id": seq_id, "subject": subj_id,
                "activity": act_id, "trial": trial_id,
                "start_frame": start, "label": label,
            })
            seq_id += 1
            start += STRIDE

    X = np.array(all_X, dtype=np.float32)  # (N, T, V, C)
    y = np.array(all_y, dtype=np.int64)

    np.save(os.path.join(out_dir, "X.npy"), X)
    np.save(os.path.join(out_dir, "y.npy"), y)

    with open(os.path.join(out_dir, "meta.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["seq_id","subject","activity","trial","start_frame","label"])
        w.writeheader()
        w.writerows(meta_rows)

    print(f"\nX shape  : {X.shape}   (N, T={WINDOW_SIZE}, V={N_JOINTS}, C={N_COORDS})")
    print(f"y shape  : {y.shape}")
    print(f"FALL     : {(y==1).sum()} sequences")
    print(f"NO-FALL  : {(y==0).sum()} sequences")
    print(f"\nSaved to : {out_dir}")
    print("\nST-GCN input: X.transpose(0,3,1,2)[:,None]  -> (N, C, T, V, 1)")
    print("TCN input   : X.reshape(N, T, -1)           -> (N, T, V*C)")


if __name__ == "__main__":
    main()
