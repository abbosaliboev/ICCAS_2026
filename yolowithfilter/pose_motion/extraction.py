from pathlib import Path

import numpy as np
import pandas as pd

from .config import ExtractionConfig, ScaleConfig
from .constants import KEYPOINT_NAMES


def _video_fps(video_path: Path) -> float:
    try:
        import cv2
    except ImportError as exc:
        raise RuntimeError("Pose extraction requires opencv-python.") from exc

    capture = cv2.VideoCapture(str(video_path))
    try:
        fps = float(capture.get(cv2.CAP_PROP_FPS))
    finally:
        capture.release()
    if not np.isfinite(fps) or fps <= 0:
        raise ValueError(f"Could not determine FPS for {video_path}")
    return fps


def extract_pose_data(
    video_path: Path,
    extraction: ExtractionConfig,
    scale: ScaleConfig,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Extract all keypoints, valid mid-hip positions, and frame scale factors."""
    try:
        from ultralytics import YOLO
    except ImportError as exc:
        raise RuntimeError("Pose extraction requires ultralytics.") from exc

    video_path = Path(video_path)
    if not video_path.is_file():
        raise FileNotFoundError(f"Video not found: {video_path}")

    fps = _video_fps(video_path)
    model = YOLO(str(extraction.model_path))
    all_rows: list[dict[str, float | int]] = []
    hip_rows: list[dict[str, float | int | str]] = []
    scale_rows: list[dict[str, float | int]] = []

    for frame_index, result in enumerate(
        model.predict(source=str(video_path), stream=True, verbose=False)
    ):
        if result.keypoints is None or len(result.keypoints.xy) <= extraction.person_index:
            continue

        keypoints = result.keypoints.xy[extraction.person_index]
        confidences = result.keypoints.conf[extraction.person_index]
        time_sec = frame_index / fps
        row: dict[str, float | int] = {"frame": frame_index, "time": time_sec}

        for index, name in enumerate(KEYPOINT_NAMES):
            row[f"{name}_x"] = keypoints[index][0].item()
            row[f"{name}_y"] = keypoints[index][1].item()
            row[f"{name}_conf"] = confidences[index].item()
        all_rows.append(row)

        _append_hip_row(hip_rows, row, extraction.confidence_threshold)
        _append_scale_row(scale_rows, row, scale, extraction.confidence_threshold)

    if not all_rows:
        raise ValueError(f"No pose was detected in {video_path}")

    hip_columns = ("frame", "time", "hip_x", "hip_y", "hip_conf", "selected_hip")
    scale_columns = ("frame", "time", "shoulder_ankle_pixel", "scale_m_per_pixel")
    return (
        pd.DataFrame(all_rows),
        pd.DataFrame(hip_rows, columns=hip_columns),
        pd.DataFrame(scale_rows, columns=scale_columns),
    )


def _append_hip_row(
    rows: list[dict[str, float | int | str]],
    keypoints: dict[str, float | int],
    threshold: float,
) -> None:
    left_conf = float(keypoints["left_hip_conf"])
    right_conf = float(keypoints["right_hip_conf"])
    if min(left_conf, right_conf) < threshold:
        return
    rows.append(
        {
            "frame": keypoints["frame"],
            "time": keypoints["time"],
            "hip_x": (float(keypoints["left_hip_x"]) + float(keypoints["right_hip_x"])) / 2,
            "hip_y": (float(keypoints["left_hip_y"]) + float(keypoints["right_hip_y"])) / 2,
            "hip_conf": (left_conf + right_conf) / 2,
            "selected_hip": "mid",
        }
    )


def _append_scale_row(
    rows: list[dict[str, float | int]],
    keypoints: dict[str, float | int],
    config: ScaleConfig,
    threshold: float,
) -> None:
    names = ("left_shoulder", "right_shoulder", "left_ankle", "right_ankle")
    if min(float(keypoints[f"{name}_conf"]) for name in names) < threshold:
        return

    shoulder = np.array(
        [
            (float(keypoints["left_shoulder_x"]) + float(keypoints["right_shoulder_x"])) / 2,
            (float(keypoints["left_shoulder_y"]) + float(keypoints["right_shoulder_y"])) / 2,
        ]
    )
    ankle = np.array(
        [
            (float(keypoints["left_ankle_x"]) + float(keypoints["right_ankle_x"])) / 2,
            (float(keypoints["left_ankle_y"]) + float(keypoints["right_ankle_y"])) / 2,
        ]
    )
    pixel_length = float(np.linalg.norm(shoulder - ankle))
    if pixel_length <= 0:
        return
    rows.append(
        {
            "frame": keypoints["frame"],
            "time": keypoints["time"],
            "shoulder_ankle_pixel": pixel_length,
            "scale_m_per_pixel": config.shoulder_ankle_length_m / pixel_length,
        }
    )
