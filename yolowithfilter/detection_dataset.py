from ultralytics import YOLO
import csv
import cv2
import numpy as np

model = YOLO("yolo11n-pose.pt")

VIDEO_PATH = "/Users/parkjonghyuk/Desktop/ICCAS/ICCAS_2026/yolowithfilter/yaxis_test_2_second_squat.mov"

# FPS 읽기
cap = cv2.VideoCapture("/Users/parkjonghyuk/Desktop/ICCAS/ICCAS_2026/yolowithfilter/yaxis_test_2_second_squat.mov")
fps = cap.get(cv2.CAP_PROP_FPS)
cap.release()

# COCO 17 Keypoints
KEYPOINT_NAMES = [
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
    "right_ankle"
]

# -------------------------------
# all_keypoints.csv 헤더 생성
# -------------------------------

all_header = ["frame", "time"]

for name in KEYPOINT_NAMES:
    all_header.extend([
        f"{name}_x",
        f"{name}_y",
        f"{name}_conf"
    ])

hip_file = open(
    "hip_positions_video.csv",
    "w",
    newline=""
)

all_file = open(
    "all_keypoints_video.csv",
    "w",
    newline=""
)

scale_file = open(
    "scale_factors.csv",
    "w",
    newline=""
)

scale_writer = csv.writer(scale_file)

scale_writer.writerow([
    "frame",
    "time",
    "shoulder_ankle_pixel",
    "scale_m_per_pixel"
])

hip_writer = csv.writer(hip_file)
all_writer = csv.writer(all_file)

hip_writer.writerow([
    "frame",
    "time",
    "hip_x",
    "hip_y",
    "hip_conf",
    "selected_hip"
])

all_writer.writerow(all_header)

frame_idx = 0

for result in model.predict(
    source="/Users/parkjonghyuk/Desktop/ICCAS/ICCAS_2026/yolowithfilter/yaxis_test_2_second_squat.mov",
    stream=True,
    verbose=False
):

    time_sec = frame_idx / fps

    if (
        result.keypoints is None
        or len(result.keypoints.xy) == 0
    ):
        frame_idx += 1
        continue

    kpts = result.keypoints.xy[0]
    confs = result.keypoints.conf[0]

    # ==================================
    # Scale 계산
    # ==================================

    REAL_HEIGHT = 1.84
    SHOULDER_ANKLE_RATIO = 0.867 # 다른 책에서 찾은 0.779는 속도 가속도 절대값 오차가 커서 논문과 동일한 0.867로 높여놨다. 
    REAL_SHOULDER_ANKLE = (
        REAL_HEIGHT *
        SHOULDER_ANKLE_RATIO
    )

    left_shoulder_conf = confs[5].item()
    right_shoulder_conf = confs[6].item()

    left_ankle_conf = confs[15].item()
    right_ankle_conf = confs[16].item()

    if (    
        left_shoulder_conf >= 0.5 and
        right_shoulder_conf >= 0.5 and
        left_ankle_conf >= 0.5 and
        right_ankle_conf >= 0.5
    ):

        shoulder_x = (
            kpts[5][0].item() +
            kpts[6][0].item()
        ) / 2

        shoulder_y = (
            kpts[5][1].item() +
            kpts[6][1].item()
        ) / 2

        ankle_x = (
            kpts[15][0].item() +
            kpts[16][0].item()
        ) / 2

        ankle_y = (
            kpts[15][1].item() +
            kpts[16][1].item()
        ) / 2

        shoulder_ankle_pixel = np.sqrt(
            (shoulder_x - ankle_x)**2 +
            (shoulder_y - ankle_y)**2
        )

        scale_m_per_pixel = (
            REAL_SHOULDER_ANKLE /
            shoulder_ankle_pixel
        )

        scale_writer.writerow([
            frame_idx,
            time_sec,
            shoulder_ankle_pixel,
            scale_m_per_pixel
        ])

    # ==================================
    # all_keypoints.csv 저장
    # ==================================

    row = [frame_idx, time_sec]

    for i in range(17):

        row.extend([
            kpts[i][0].item(),
            kpts[i][1].item(),
            confs[i].item()
        ])

    all_writer.writerow(row)

    # ==================================
    # hip_positions.csv 저장
    # ==================================

    left_conf = confs[11].item()
    right_conf = confs[12].item()

    # 둘 다 검출된 경우만 사용
    if left_conf >= 0.5 and right_conf >= 0.5:

        left_hip_x = kpts[11][0].item()
        left_hip_y = kpts[11][1].item()

        right_hip_x = kpts[12][0].item()
        right_hip_y = kpts[12][1].item()

        # Mid-Hip
        hip_x = (
            left_hip_x +
            right_hip_x
        ) / 2

        hip_y = (
            left_hip_y +
            right_hip_y
        ) / 2

        # 평균 confidence
        hip_conf = (
            left_conf +
            right_conf
        ) / 2

        hip_writer.writerow([
            frame_idx,
            time_sec,
            hip_x,
            hip_y,
            hip_conf,
            "mid"
        ])

    frame_idx += 1

hip_file.close()
all_file.close()
scale_file.close()


print("저장 완료")