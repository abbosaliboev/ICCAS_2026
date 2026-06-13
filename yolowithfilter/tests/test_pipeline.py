import unittest

import numpy as np
import pandas as pd

from pose_motion.config import AnalysisConfig, ScaleConfig
from pose_motion.constants import KEYPOINT_NAMES
from pose_motion.kinematics import analyze_motion
from pose_motion.scale import estimate_scale


class ScaleTests(unittest.TestCase):
    def test_estimate_scale_uses_frame_value_not_dataframe_index(self):
        rows = []
        for index in range(40):
            row = {"frame": 100 + index, "time": index / 60}
            for name in KEYPOINT_NAMES:
                row[f"{name}_x"] = 0.0
                row[f"{name}_y"] = 0.0
            row.update(
                {
                    "left_shoulder_x": -1.0,
                    "right_shoulder_x": 1.0,
                    "left_hip_y": 40.0,
                    "right_hip_y": 40.0,
                    "left_knee_y": 70.0,
                    "right_knee_y": 70.0,
                    "left_ankle_y": 100.0 + index,
                    "right_ankle_y": 100.0 + index,
                }
            )
            rows.append(row)

        result = estimate_scale(pd.DataFrame(rows), ScaleConfig(window_size=5))
        self.assertEqual(result["best_frame"].iloc[0], 139)
        self.assertGreater(result["best_scale"].iloc[0], 0)


class KinematicsTests(unittest.TestCase):
    def test_analyze_motion_returns_expected_columns_and_length(self):
        time = np.arange(180) / 60
        hips = pd.DataFrame({"time": time, "hip_y": 100 + 10 * np.sin(2 * np.pi * time)})
        velocity, acceleration, combined = analyze_motion(
            hips, 0.01, AnalysisConfig()
        )
        self.assertEqual(len(combined), len(hips))
        self.assertEqual(list(velocity.columns), ["time", "video_velocity_m_s"])
        self.assertEqual(list(acceleration.columns), ["time", "video_acceleration"])
        self.assertTrue(np.isfinite(combined.to_numpy()).all())


if __name__ == "__main__":
    unittest.main()
