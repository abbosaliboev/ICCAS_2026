import numpy as np
import pandas as pd

from .config import ScaleConfig


def _distance(df: pd.DataFrame, first: str, second: str) -> np.ndarray:
    return np.hypot(
        df[f"{first}_x"].to_numpy() - df[f"{second}_x"].to_numpy(),
        df[f"{first}_y"].to_numpy() - df[f"{second}_y"].to_numpy(),
    )


def _midpoint(df: pd.DataFrame, left: str, right: str, name: str) -> pd.DataFrame:
    return pd.DataFrame(
        {
            f"{name}_x": (df[f"{left}_x"] + df[f"{right}_x"]) / 2,
            f"{name}_y": (df[f"{left}_y"] + df[f"{right}_y"]) / 2,
        }
    )


def _normalize(values: np.ndarray, fill_nan_with_max: bool = False) -> np.ndarray:
    values = np.asarray(values, dtype=float).copy()
    finite = np.isfinite(values)
    if not finite.any():
        return np.zeros_like(values)
    if fill_nan_with_max:
        values[~finite] = np.nanmax(values)
    else:
        values[~finite] = np.nanmin(values)
    value_range = values.max() - values.min()
    return np.zeros_like(values) if value_range == 0 else (values - values.min()) / value_range


def estimate_scale(keypoints: pd.DataFrame, config: ScaleConfig) -> pd.DataFrame:
    """Select a stable, large, late-frame body scale estimate."""
    if keypoints.empty:
        raise ValueError("Cannot estimate scale from an empty keypoint table.")

    shoulder = _midpoint(keypoints, "left_shoulder", "right_shoulder", "shoulder")
    hip = _midpoint(keypoints, "left_hip", "right_hip", "hip")
    knee = _midpoint(keypoints, "left_knee", "right_knee", "knee")
    ankle = _midpoint(keypoints, "left_ankle", "right_ankle", "ankle")
    points = pd.concat([shoulder, hip, knee, ankle], axis=1)

    shoulder_ankle = _distance(points, "shoulder", "ankle")
    if not np.isfinite(shoulder_ankle).any() or np.nanmax(shoulder_ankle) <= 0:
        raise ValueError("Shoulder-to-ankle pixel lengths are invalid.")

    denominator = shoulder_ankle + np.finfo(float).eps
    ratios = np.column_stack(
        [
            _distance(points, "shoulder", "hip") / denominator,
            _distance(points, "hip", "ankle") / denominator,
            _distance(points, "shoulder", "knee") / denominator,
        ]
    )
    ratio_variation = (
        pd.DataFrame(ratios)
        .rolling(window=config.window_size, min_periods=config.window_size)
        .std(ddof=0)
        .sum(axis=1, min_count=ratios.shape[1])
        .shift(1)
        .to_numpy()
    )
    time_score = np.linspace(0.0, 1.0, len(keypoints)) if len(keypoints) > 1 else np.zeros(1)
    score = (
        config.time_weight * time_score
        + config.length_weight * _normalize(shoulder_ankle)
        - config.ratio_weight * _normalize(ratio_variation, fill_nan_with_max=True)
    )
    best_position = int(np.nanargmax(score))
    pixel_length = float(shoulder_ankle[best_position])
    if pixel_length <= 0:
        raise ValueError("Selected shoulder-to-ankle pixel length must be positive.")

    result: dict[str, list[float | int]] = {
        "best_frame": [int(keypoints.iloc[best_position]["frame"])],
        "best_scale": [config.shoulder_ankle_length_m / pixel_length],
    }
    if "time" in keypoints:
        result["best_time"] = [float(keypoints.iloc[best_position]["time"])]
    return pd.DataFrame(result)
