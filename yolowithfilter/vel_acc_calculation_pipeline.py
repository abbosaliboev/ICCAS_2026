import subprocess
import sys

print("=" * 50)
print("STEP 1 : YOLO Pose Extraction")
print("=" * 50)

result = subprocess.run(
    [sys.executable, "detection_dataset.py"]
)

if result.returncode != 0:
    raise RuntimeError(
        "detection_dataset.py failed."
    )

print()
print("=" * 50)
print("STEP 2 : Scale Estimation")
print("=" * 50)

result = subprocess.run(
    [sys.executable, "scale_discover.py"]
)

if result.returncode != 0:
    raise RuntimeError(
        "scale_discover.py failed."
    )

print()
print("=" * 50)
print("STEP 3 : Motion Analysis")
print("=" * 50)

result = subprocess.run(
    [sys.executable, "filter.py"]
)

if result.returncode != 0:
    raise RuntimeError(
        "filter.py failed."
    )

print()
print("=" * 50)
print("Pipeline Complete")
print("=" * 50)

print()
print("Generated Files")

print("- all_keypoints_video.csv")
print("- hip_positions_video.csv")
print("- scale_factors.csv")
print("- selected_scale.csv")
print("- video_velocity.csv")
print("- video_acceleration.csv")
print("- hip_acceleration.csv")