KEYPOINT_NAMES = (
    "nose",
    "left_eye",
    "right_eye",
    "left_ear",
    "right_ear",
    "left_shoulder",
    "right_shoulder",
    "left_elbow",
    "right_elbow",
    "left_wrist",
    "right_wrist",
    "left_hip",
    "right_hip",
    "left_knee",
    "right_knee",
    "left_ankle",
    "right_ankle",
)

KEYPOINT_INDEX = {name: index for index, name in enumerate(KEYPOINT_NAMES)}

ALL_KEYPOINTS_FILENAME = "all_keypoints_video.csv"
HIP_POSITIONS_FILENAME = "hip_positions_video.csv"
SCALE_FACTORS_FILENAME = "scale_factors.csv"
SELECTED_SCALE_FILENAME = "selected_scale.csv"
VELOCITY_FILENAME = "video_velocity.csv"
ACCELERATION_FILENAME = "video_acceleration.csv"
COMBINED_FILENAME = "hip_acceleration.csv"
