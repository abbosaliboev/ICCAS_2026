import numpy as np
import pandas as pd
from scipy.signal import butter, filtfilt

from .config import AnalysisConfig


def _low_pass(values: np.ndarray, sampling_hz: float, cutoff_hz: float, order: int) -> np.ndarray:
    nyquist = sampling_hz / 2
    if not 0 < cutoff_hz < nyquist:
        raise ValueError(f"Cutoff frequency {cutoff_hz:g} Hz must be below Nyquist {nyquist:g} Hz.")
    b, a = butter(N=order, Wn=cutoff_hz / nyquist, btype="low")
    pad_length = 3 * max(len(a), len(b))
    if len(values) <= pad_length:
        raise ValueError(f"At least {pad_length + 1} samples are required for filtering.")
    return filtfilt(b, a, values)


def analyze_motion(
    hip_positions: pd.DataFrame,
    scale_m_per_pixel: float,
    config: AnalysisConfig,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """Filter mid-hip position and calculate vertical velocity and acceleration."""
    if len(hip_positions) < 2:
        raise ValueError("At least two hip-position samples are required.")

    time = hip_positions["time"].to_numpy(dtype=float)
    position = hip_positions["hip_y"].to_numpy(dtype=float)
    time_steps = np.diff(time)
    if not np.all(np.isfinite(time_steps)) or np.any(time_steps <= 0):
        raise ValueError("Hip-position timestamps must be finite and strictly increasing.")
    sampling_hz = 1 / np.mean(time_steps)

    filtered_position = _low_pass(
        position, sampling_hz, config.position_cutoff_hz, config.filter_order
    )
    raw_velocity = np.gradient(position, time)
    position_velocity = np.gradient(filtered_position, time)
    filtered_velocity = _low_pass(
        position_velocity, sampling_hz, config.velocity_cutoff_hz, config.filter_order
    )
    raw_acceleration = np.gradient(raw_velocity, time)
    position_acceleration = np.gradient(position_velocity, time)
    filtered_acceleration = _low_pass(
        np.gradient(filtered_velocity, time),
        sampling_hz,
        config.acceleration_cutoff_hz,
        config.filter_order,
    )

    direction = -1.0 if config.invert_vertical_axis else 1.0
    velocity_m_s = direction * filtered_velocity * scale_m_per_pixel
    acceleration_m_s2 = direction * filtered_acceleration * scale_m_per_pixel
    velocity = pd.DataFrame({"time": time, "video_velocity_m_s": velocity_m_s})
    acceleration = pd.DataFrame({"time": time, "video_acceleration": acceleration_m_s2})
    combined = pd.DataFrame(
        {
            "time": time,
            "raw_position": position,
            "filtered_position": filtered_position,
            "velocity_pixel_s": filtered_velocity,
            "velocity_m_s": velocity_m_s,
            "acceleration_pixel_s2": filtered_acceleration,
            "acceleration_m_s2": acceleration_m_s2,
        }
    )
    combined.attrs["plot_series"] = {
        "raw_velocity": raw_velocity,
        "position_velocity": position_velocity,
        "raw_acceleration": raw_acceleration,
        "position_acceleration": position_acceleration,
    }
    return velocity, acceleration, combined


def plot_motion(combined: pd.DataFrame) -> None:
    import matplotlib.pyplot as plt

    time = combined["time"]
    extra = combined.attrs.get("plot_series", {})
    figure, axes = plt.subplots(3, 1, figsize=(14, 14))
    axes[0].plot(time, combined["raw_position"], label="Raw Position")
    axes[0].plot(time, combined["filtered_position"], label="Filtered Position")
    axes[1].plot(time, extra.get("raw_velocity"), label="Raw Velocity")
    axes[1].plot(time, extra.get("position_velocity"), label="Velocity from Filtered Position")
    axes[1].plot(time, combined["velocity_pixel_s"], label="Filtered Velocity")
    axes[2].plot(time, extra.get("raw_acceleration"), label="Raw Acceleration")
    axes[2].plot(time, extra.get("position_acceleration"), label="Acceleration from Filtered Position")
    axes[2].plot(time, combined["acceleration_pixel_s2"], label="Filtered Acceleration")
    for axis, title, unit in zip(
        axes,
        ("Mid-Hip Position", "Velocity", "Acceleration"),
        ("Position (pixel)", "Velocity (pixel/s)", "Acceleration (pixel/s^2)"),
    ):
        axis.set_title(title)
        axis.set_xlabel("Time (s)")
        axis.set_ylabel(unit)
        axis.grid()
        axis.legend()
    figure.tight_layout()
    plt.show()
