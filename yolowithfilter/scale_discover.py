import pandas as pd
import numpy as np

# =====================================
# 설정
# =====================================

HEIGHT = 1.84
SHOULDER_ANKLE_RATIO = 0.867

REAL_SHOULDER_ANKLE = (
    HEIGHT * SHOULDER_ANKLE_RATIO
)

WINDOW = 30  # 0.5초 (60fps 기준)

# =====================================
# CSV 읽기
# =====================================

df = pd.read_csv("all_keypoints_video.csv")

# =====================================
# 거리 함수
# =====================================

def dist(x1, y1, x2, y2):
    return np.sqrt(
        (x1 - x2)**2 +
        (y1 - y2)**2
    )

# =====================================
# Mid Points
# =====================================

shoulder_x = (
    df["left_shoulder_x"]
    + df["right_shoulder_x"]
) / 2

shoulder_y = (
    df["left_shoulder_y"]
    + df["right_shoulder_y"]
) / 2

hip_x = (
    df["left_hip_x"]
    + df["right_hip_x"]
) / 2

hip_y = (
    df["left_hip_y"]
    + df["right_hip_y"]
) / 2

knee_x = (
    df["left_knee_x"]
    + df["right_knee_x"]
) / 2

knee_y = (
    df["left_knee_y"]
    + df["right_knee_y"]
) / 2

ankle_x = (
    df["left_ankle_x"]
    + df["right_ankle_x"]
) / 2

ankle_y = (
    df["left_ankle_y"]
    + df["right_ankle_y"]
) / 2

# =====================================
# 분절 길이
# =====================================

L_SA = dist(
    shoulder_x, shoulder_y,
    ankle_x, ankle_y
)

L_SH = dist(
    shoulder_x, shoulder_y,
    hip_x, hip_y
)

L_HA = dist(
    hip_x, hip_y,
    ankle_x, ankle_y
)

L_SK = dist(
    shoulder_x, shoulder_y,
    knee_x, knee_y
)

# =====================================
# 분절 비율
# =====================================

r1 = L_SH / (L_SA + 1e-6)
r2 = L_HA / (L_SA + 1e-6)
r3 = L_SK / (L_SA + 1e-6)

# =====================================
# Ratio Variation
# =====================================

ratio_var = np.full(
    len(df),
    np.nan
)

for i in range(WINDOW, len(df)):

    ratio_var[i] = (
        np.std(r1[i-WINDOW:i])
        +
        np.std(r2[i-WINDOW:i])
        +
        np.std(r3[i-WINDOW:i])
    )

# =====================================
# 정규화
# =====================================

ratio_var_valid = ratio_var.copy()

ratio_var_valid[np.isnan(
    ratio_var_valid
)] = np.nanmax(
    ratio_var_valid
)

ratio_score = (
    ratio_var_valid
    - np.min(ratio_var_valid)
)

ratio_score = (
    ratio_score
    / np.max(ratio_score)
)

length_score = (
    L_SA
    - np.min(L_SA)
)

length_score = (
    length_score
    / np.max(length_score)
)

time_score = np.arange(
    len(df)
) / (len(df)-1)

# =====================================
# 최종 점수
# =====================================

score = (
    3.0 * time_score
    +
    2.0 * length_score
    -
    1.0 * ratio_score
)

best_idx = np.argmax(score)

# =====================================
# Scale 계산
# =====================================

best_scale = (
    REAL_SHOULDER_ANKLE
    / L_SA[best_idx]
)

# =====================================
# 결과 출력
# =====================================

print()
print("Best Frame :", best_idx)

if "time" in df.columns:
    print(
        "Time       :",
        df.loc[best_idx, "time"]
    )

print(
    "Scale      :",
    best_scale
)

# =====================================
# 저장
# =====================================

result = pd.DataFrame({
    "best_frame":[best_idx],
    "best_scale":[best_scale]
})

if "time" in df.columns:
    result["best_time"] = [
        df.loc[best_idx, "time"]
    ]

result.to_csv(
    "selected_scale.csv",
    index=False
)

print()
print(
    "Saved : selected_scale.csv"
)
print(best_idx)
print(df.loc[best_idx, "time"])