import pandas as pd
import numpy as np
from scipy.signal import butter, filtfilt
import matplotlib.pyplot as plt

# CSV 읽기
df = pd.read_csv("/Users/parkjonghyuk/Desktop/ICCAS/ICCAS_2026/yolowithfilter/hip_data.csv")

t = df["elapsed_time"].values
y = df["mid_hip_y"].values

# 샘플링 주파수 계산
fs = 1 / np.mean(np.diff(t))

print("Sampling Frequency =", fs)

# =====================================
# Position Filter (5 Hz)
# =====================================

fc = 5

b, a = butter(
    N=4,
    Wn=fc / (fs / 2),
    btype="low"
)

y_filtered = filtfilt(b, a, y)

# =====================================
# Velocity
# =====================================

velocity_raw = np.gradient(y, t)

velocity_filtered = np.gradient(
    y_filtered,
    t
)

# =====================================
# Velocity Filter (10 Hz)
# =====================================

fc = 10

c, d = butter(
    N=4,
    Wn=fc / (fs / 2),
    btype="low"
)

V_filtered = filtfilt(
    c,
    d,
    velocity_filtered
)

# =====================================
# Acceleration
# =====================================

acceleration_raw = np.gradient(
    velocity_raw,
    t
)

acceleration_filtered = np.gradient(
    velocity_filtered,
    t
)

A_filtered = np.gradient(
    V_filtered,
    t
)

# =====================================
# Acceleration Filter (8 Hz)
# =====================================

fc = 8

e, f = butter(
    N=4,
    Wn=fc / (fs / 2),
    btype="low"
)

A_filtered2 = filtfilt(
    e,
    f,
    A_filtered
)

# =====================================
# Plot
# =====================================

plt.figure(figsize=(14,14))

# -------------------------------------
# Position
# -------------------------------------

plt.subplot(3,1,1)

plt.plot(
    t,
    y,
    label="Raw Position"
)

plt.plot(
    t,
    y_filtered,
    label="5Hz Filtered Position"
)

plt.xlabel("Time (s)")
plt.ylabel("Position (pixel)")
plt.title("Mid-Hip Position")

plt.legend()
plt.grid()

# -------------------------------------
# Velocity
# -------------------------------------

plt.subplot(3,1,2)

plt.plot(
    t,
    velocity_raw,
    label="Raw Velocity"
)

plt.plot(
    t,
    velocity_filtered,
    label="Velocity from 5Hz Position"
)

plt.plot(
    t,
    V_filtered,
    label="10Hz Filtered Velocity"
)

plt.xlabel("Time (s)")
plt.ylabel("Velocity (pixel/s)")
plt.title("Velocity")

plt.legend()
plt.grid()

# -------------------------------------
# Acceleration
# -------------------------------------

plt.subplot(3,1,3)

plt.plot(
    t,
    acceleration_raw,
    label="Raw Acceleration"
)

plt.plot(
    t,
    acceleration_filtered,
    label="Acceleration from 5Hz Position"
)

plt.plot(
    t,
    A_filtered2,
    label="Final Acceleration (8Hz Filter)"
)

plt.xlabel("Time (s)")
plt.ylabel("Acceleration (pixel/s²)")
plt.title("Acceleration")

plt.legend()
plt.grid()

plt.subplots_adjust(hspace=0.6)

plt.show()