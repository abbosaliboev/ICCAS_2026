# 욜로 기본 작동 및 욜로 포즈의 출력 데이터 형식, 중간 엉덩이 계산, 객채 불러서 컨피던스 프린트하는 코드 
'''
from ultralytics import YOLO

model = YOLO("yolo11n-pose.pt")

for result in model.predict(
    source=1,      # 네 맥북 카메라
    stream=True,
    show=True
):

    if result.keypoints is not None:

        kpts = result.keypoints.xy

        if len(kpts) > 0:

            left_hip_y = kpts[0][11][1]
            right_hip_y = kpts[0][12][1]
            
            mid_hip_y = (left_hip_y + right_hip_y) / 2

            print("Left Hip :", left_hip_y)
            print("Right Hip:", right_hip_y)
            print("Mid_Hip_y:", mid_hip_y)
            print(result.keypoints.conf)

print(kpts.size()) # kpts는 욜로 포즈가 저장하는 인식 결과 데이터다. 데이터는 (인식되는 사람의 수, 관절 넘버, 화면 차원 = x,y 좌표)
'''


from ultralytics import YOLO
import time
import csv

# YOLO 모델 로드
model = YOLO("yolo11n-pose.pt")

# 이전 데이터 저장용
prev_mid_hip_y = None
prev_time = None

# 첫 유효 프레임 기준 시간
start_time = None

# CSV 파일 생성
csv_file = open("hip_data.csv", "w", newline="")
writer = csv.writer(csv_file)

writer.writerow([
    "elapsed_time",
    "mid_hip_y",
    "velocity",
    "left_conf",
    "right_conf"
])

try:

    for result in model.predict(
        source=1,
        stream=True,
        show=True
    ):

        if result.keypoints is None:
            continue

        kpts = result.keypoints.xy

        if len(kpts) == 0:
            continue

        # Hip 좌표
        left_hip_y = kpts[0][11][1]
        right_hip_y = kpts[0][12][1]

        # Confidence
        left_conf = result.keypoints.conf[0][11]
        right_conf = result.keypoints.conf[0][12]

        # Confidence 필터
        if left_conf < 0.5 or right_conf < 0.5:
            continue

        # Mid-Hip 계산
        mid_hip_y = (left_hip_y + right_hip_y) / 2

        current_time = time.time()

        # 첫 유효 프레임
        if prev_mid_hip_y is None:

            start_time = current_time

            prev_mid_hip_y = mid_hip_y.item()
            prev_time = current_time

            print("=== Measurement Started ===")
            continue

        # 시간 차
        dt = current_time - prev_time

        # 속도 계산
        velocity = (
            mid_hip_y.item() - prev_mid_hip_y
        ) / dt

        # 경과 시간
        elapsed_time = current_time - start_time

        # CSV 저장
        writer.writerow([
            elapsed_time,
            mid_hip_y.item(),
            velocity,
            left_conf.item(),
            right_conf.item()
        ])

        # 디버그 출력
        print(f"Time      : {elapsed_time:.3f} s")
        print(f"Velocity  : {velocity:.2f} pixel/s")
        print(f"Mid_Hip_y : {mid_hip_y.item():.2f}")
        print(
            f"L_conf={left_conf:.3f}, "
            f"R_conf={right_conf:.3f}"
        )
        print("-" * 40)

        # 이전값 업데이트
        prev_mid_hip_y = mid_hip_y.item()
        prev_time = current_time

except KeyboardInterrupt:
    print("종료")

finally:
    csv_file.close()
    print("CSV 저장 완료 : hip_data.csv")