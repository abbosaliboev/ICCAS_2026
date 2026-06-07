import pandas as pd
import numpy as np
from scipy.signal import butter, filtfilt
import matplotlib.pyplot as plt

# =====================================
# Input
# =====================================

CSV_PATH = "hip_positions_video.csv"

# =====================================
# Load Scale Factor
# =====================================

scale_df = pd.read_csv(
    "selected_scale.csv"
)

SCALE = scale_df[
    "best_scale"
].iloc[0]

print(
    "Scale =",
    SCALE
)

# =====================================
# Read CSV
# =====================================

df = pd.read_csv(CSV_PATH)

t = df["time"].values
y = df["hip_y"].values

# =====================================
# Sampling Frequency
# =====================================

fs = 1 / np.mean(np.diff(t))

print("Sampling Frequency =", fs)
print("Scale =", SCALE)

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
# Pixel/s -> m/s
# =====================================

velocity_m_s = -V_filtered * SCALE

vel_df = pd.DataFrame({
    "time": t,
    "video_velocity_m_s": velocity_m_s
})

vel_df.to_csv(
    "video_velocity.csv",
    index=False
)

print("Saved : video_velocity.csv")

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
# Pixel/s² -> m/s²
# =====================================

acceleration_m_s2 = -A_filtered2 * SCALE

acc_df = pd.DataFrame({
    "time": t,
    "video_acceleration": acceleration_m_s2
})

acc_df.to_csv(
    "video_acceleration.csv",
    index=False
)

print("Saved : video_acceleration.csv")

# =====================================
# Save Combined CSV
# =====================================

result_df = pd.DataFrame({
    "time": t,
    "raw_position": y,
    "filtered_position": y_filtered,
    "velocity_pixel_s": V_filtered,
    "velocity_m_s": velocity_m_s,
    "acceleration_pixel_s2": A_filtered2,
    "acceleration_m_s2": acceleration_m_s2
})

result_df.to_csv(
    "hip_acceleration.csv",
    index=False
)

print("Saved : hip_acceleration.csv")

# =====================================
# Plot
# =====================================

plt.figure(figsize=(14,14))

# Position
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

# Velocity
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

# Acceleration
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