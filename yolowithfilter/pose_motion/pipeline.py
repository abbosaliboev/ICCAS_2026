from pathlib import Path

import pandas as pd

from .config import AnalysisConfig, ExtractionConfig, PipelineConfig, ScaleConfig
from .constants import (
    ACCELERATION_FILENAME,
    ALL_KEYPOINTS_FILENAME,
    COMBINED_FILENAME,
    HIP_POSITIONS_FILENAME,
    SCALE_FACTORS_FILENAME,
    SELECTED_SCALE_FILENAME,
    VELOCITY_FILENAME,
)
from .extraction import extract_pose_data
from .kinematics import analyze_motion, plot_motion
from .scale import estimate_scale


def save_pose_data(
    video_path: Path,
    output_dir: Path,
    extraction: ExtractionConfig,
    scale: ScaleConfig,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    output_dir.mkdir(parents=True, exist_ok=True)
    all_keypoints, hip_positions, scale_factors = extract_pose_data(video_path, extraction, scale)
    all_keypoints.to_csv(output_dir / ALL_KEYPOINTS_FILENAME, index=False)
    hip_positions.to_csv(output_dir / HIP_POSITIONS_FILENAME, index=False)
    scale_factors.to_csv(output_dir / SCALE_FACTORS_FILENAME, index=False)
    return all_keypoints, hip_positions, scale_factors


def save_scale(keypoints_path: Path, output_path: Path, config: ScaleConfig) -> pd.DataFrame:
    selected_scale = estimate_scale(pd.read_csv(keypoints_path), config)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    selected_scale.to_csv(output_path, index=False)
    return selected_scale


def save_analysis(
    hip_positions_path: Path,
    selected_scale_path: Path,
    output_dir: Path,
    config: AnalysisConfig,
    show_plot: bool = False,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    scale = float(pd.read_csv(selected_scale_path)["best_scale"].iloc[0])
    velocity, acceleration, combined = analyze_motion(
        pd.read_csv(hip_positions_path), scale, config
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    velocity.to_csv(output_dir / VELOCITY_FILENAME, index=False)
    acceleration.to_csv(output_dir / ACCELERATION_FILENAME, index=False)
    combined.to_csv(output_dir / COMBINED_FILENAME, index=False)
    if show_plot:
        plot_motion(combined)
    return velocity, acceleration, combined


def run_pipeline(config: PipelineConfig) -> dict[str, Path]:
    """Run extraction, scale estimation, and motion analysis."""
    output_dir = config.output_dir
    all_keypoints, _, _ = save_pose_data(
        config.video_path, output_dir, config.extraction, config.scale
    )
    selected_scale = estimate_scale(all_keypoints, config.scale)
    selected_scale.to_csv(output_dir / SELECTED_SCALE_FILENAME, index=False)
    save_analysis(
        output_dir / HIP_POSITIONS_FILENAME,
        output_dir / SELECTED_SCALE_FILENAME,
        output_dir,
        config.analysis,
        config.show_plot,
    )
    return {
        name: output_dir / name
        for name in (
            ALL_KEYPOINTS_FILENAME,
            HIP_POSITIONS_FILENAME,
            SCALE_FACTORS_FILENAME,
            SELECTED_SCALE_FILENAME,
            VELOCITY_FILENAME,
            ACCELERATION_FILENAME,
            COMBINED_FILENAME,
        )
    }
