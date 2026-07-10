# Pose Motion Analysis

From a single monocular video, YOLO pose keypoints are converted into a metric
body scale and the **vertical velocity and acceleration of the mid-hip point in
real-world units (m/s, m/s²)**. No calibration target is needed: the subject's
own body, together with a known height, acts as the measuring stick.

## Package layout

- `pose_motion.extraction` — YOLO pose extraction; per-frame keypoints, mid-hip
  positions, and per-frame scale candidates
- `pose_motion.scale` — picks a single stable frame and derives one metric scale
  (meters per pixel) from anthropometry
- `pose_motion.kinematics` — low-pass filtering, differentiation, and pixel→meter
  conversion
- `pose_motion.pipeline` — file-based orchestration of the three stages
- `pose_motion.cli` — command-line interface (`run` / `extract` / `scale` / `analyze`)

The original four scripts (`detection_dataset.py`, `scale_discover.py`,
`filter.py`, `vel_acc_calculation_pipeline.py`) remain as thin
backward-compatible entry points that forward to the CLI.

## How it works

### 1. Pose extraction (`extraction.py`)

- `yolo11n-pose.pt` runs on every frame, giving 17 COCO keypoints (x, y, conf).
- Timestamps come from the video's own FPS: `time = frame_index / fps`.
- Three tables are produced:
  - **all keypoints** — every joint's x/y/confidence per frame.
  - **hip positions** — mid-hip point `(left_hip + right_hip) / 2`, kept only for
    frames where *both* hip confidences ≥ `confidence_threshold` (default 0.5).
  - **scale candidates** — the mid-shoulder→mid-ankle pixel length per frame,
    kept only when the four shoulder/ankle keypoints all pass the threshold.

The mid-hip vertical coordinate is used as a proxy for the body's vertical
center-of-mass motion.

### 2. Metric scale estimation (`scale.py`)

A monocular camera only produces pixels; recovering meters requires a reference
of known real length. Here that reference is the body itself:

```
shoulder_ankle_length_m = height_m × shoulder_ankle_ratio      # 1.84 × 0.867 ≈ 1.595 m
scale (m/pixel)         = shoulder_ankle_length_m / shoulder_ankle_pixel_length
```

Not every frame is a trustworthy ruler — a bent, occluded, or foreshortened pose
distorts the apparent body length. So each frame is scored and the single best
frame is chosen:

```
score =  time_weight   · time_score                      # later frames preferred (weight 3.0)
       + length_weight · normalized(shoulder_ankle_px)   # most fully-extended body (weight 2.0)
       − ratio_weight  · normalized(ratio_variation)     # most temporally stable pose (weight 1.0)
```

- `time_score` rises linearly 0→1 across the clip.
- `ratio_variation` is the rolling standard deviation (window 30) of three
  inter-joint ratios (shoulder–hip, hip–ankle, shoulder–knee, each divided by the
  shoulder–ankle length); a low value means the projected proportions are steady.

The scale from the winning frame (`best_scale`) is used for the whole clip.

### 3. Kinematics (`kinematics.py`)

Differentiation amplifies pose-estimation jitter, so a zero-phase Butterworth
low-pass filter (`filtfilt`, order 4) is applied at each stage. Real body motion
lives at low frequencies; jitter lives at high frequencies.

1. Sampling rate `sampling_hz = 1 / mean(Δt)`.
2. Low-pass the mid-hip position (cutoff 5 Hz).
3. Differentiate → velocity, then low-pass (cutoff 10 Hz).
4. Differentiate → acceleration, then low-pass (cutoff 8 Hz).
5. Flip the sign (`invert_vertical_axis`, default on) because image y grows
   downward while physical "up" should be positive.
6. Multiply the filtered pixel-domain velocity/acceleration by `scale` to get
   **m/s and m/s²**.

## Outputs

Written to `--output-dir`:

| File | Contents | Units |
| --- | --- | --- |
| `all_keypoints_video.csv` | every keypoint x/y/conf per frame | pixels |
| `hip_positions_video.csv` | mid-hip position per valid frame | pixels |
| `scale_factors.csv` | per-frame scale candidates | m/pixel |
| `selected_scale.csv` | chosen frame + `best_scale` | m/pixel |
| `video_velocity.csv` | `video_velocity_m_s` | **m/s** |
| `video_acceleration.csv` | `video_acceleration` | **m/s²** |
| `hip_acceleration.csv` | positions, plus velocity/acceleration in *both* pixel and metric columns | pixels & metric |

> **Note on `--show-plot`.** The on-screen plot is drawn in **pixel units**
> (`velocity_pixel_s`, `acceleration_pixel_s2`) — it visualizes the pre-scaling
> signal, not the final metric result. The metric values live only in the CSVs
> (`*_m_s` columns). Don't read meters off the plot.

## The final result

The deliverable is a pair of time series sampled at the video frame rate:

- **Vertical mid-hip velocity** `video_velocity_m_s` (m/s)
- **Vertical mid-hip acceleration** `video_acceleration` (m/s²)

Both share the same `time` column, so each row is one frame with its real-world
velocity and acceleration of the body's vertical center-of-mass. After the sign
flip, **positive = moving/accelerating upward, negative = downward**; a fast
downward drop shows up as a large-magnitude negative velocity followed by a
sharp acceleration spike.

Concretely, on the bundled `yaxis_test_2_second_squat.mov` (13.9 s, 813 frames)
the pipeline yields peak speeds around **1.1 m/s** and peak accelerations around
**4.6 m/s²** — physically plausible magnitudes for a squat, which is the point of
converting to metric units: the numbers are now comparable across cameras,
distances, and subjects rather than being tied to one video's pixel geometry.

This metric velocity/acceleration signal is the intended input to downstream
fall-detection logic (e.g. velocity/acceleration thresholds), where the physical
units make thresholds transferable instead of camera-specific.

## Install

```bash
python -m pip install -e .
```

The `falldetection` Conda environment already has `ultralytics` and
`opencv-python`:

```bash
conda activate falldetection
python -m pip install -e .
```

## Run

Full pipeline (extract → scale → analyze):

```bash
conda run -n falldetection python -m pose_motion run \
  yaxis_test_2_second_squat.mov \
  --height 1.84 \
  --shoulder-ankle-ratio 0.867 \
  --output-dir 0613_codex_integrate
```

Add `--show-plot` to display the (pixel-unit) velocity/acceleration graphs.

Full pipeline **with graphs** in one command:

```bash
conda run -n falldetection python -m pose_motion run \
  yaxis_test_2_second_squat.mov \
  --height 1.84 \
  --shoulder-ankle-ratio 0.867 \
  --output-dir 0613_codex_integrate \
  --show-plot
```

`--show-plot` opens three windows:

1. **Combined** (3 rows) — position / velocity / acceleration, raw + derived +
   filtered overlaid
2. **Raw** (2 rows, 4:3) — unfiltered noisy velocity + acceleration only
3. **Filtered** (2 rows, 4:3) — filtered clean velocity + acceleration only

The legacy script entry point still works and takes the same options
(it forwards to `pose_motion run`):

```bash
conda run -n falldetection python vel_acc_calculation_pipeline.py \
  yaxis_test_2_second_squat.mov \
  --height 1.84 \
  --shoulder-ankle-ratio 0.867 \
  --output-dir 0613_codex_integrate \
  --show-plot
```

Individual stages:

```bash
conda run -n falldetection python -m pose_motion extract input.mov \
  --output-dir 0613_codex_integrate

conda run -n falldetection python -m pose_motion scale \
  --keypoints 0613_codex_integrate/all_keypoints_video.csv \
  --output 0613_codex_integrate/selected_scale.csv

conda run -n falldetection python -m pose_motion analyze \
  --hips 0613_codex_integrate/hip_positions_video.csv \
  --scale 0613_codex_integrate/selected_scale.csv \
  --output-dir 0613_codex_integrate
```

See all options with `python -m pose_motion <command> --help`.

### Key options (defaults)

| Option | Default | Meaning |
| --- | --- | --- |
| `--height` | 1.84 | subject height in meters (drives the metric scale) |
| `--shoulder-ankle-ratio` | 0.867 | shoulder-ankle length as a fraction of height |
| `--confidence` | 0.5 | minimum keypoint confidence to keep a frame |
| `--scale-window` | 30 | rolling window for pose-stability scoring |
| `--position-cutoff` | 5.0 | Hz, low-pass on position |
| `--velocity-cutoff` | 10.0 | Hz, low-pass on velocity |
| `--acceleration-cutoff` | 8.0 | Hz, low-pass on acceleration |
| `--filter-order` | 4 | Butterworth order |
| `--keep-image-axis` | off | keep image y-down axis (skip the sign flip) |

> The metric **unit** is always meters, but absolute accuracy depends on how well
> `--height` and `--shoulder-ankle-ratio` match the actual subject.

---

# 포즈 기반 동작 분석

단안(monocular) 영상 한 편에서 YOLO 포즈 키포인트를 추출하고, 피험자의 신체
자체를 기준자로 삼아 **엉덩이 중앙점의 수직 속도·가속도를 실제 물리 단위(m/s,
m/s²)로** 계산합니다. 별도의 보정 도구 없이, 알고 있는 키 값과 신체 비율만으로
스케일을 복원합니다.

## 패키지 구성

- `pose_motion.extraction` — YOLO 포즈 추출; 프레임별 키포인트·엉덩이 중앙점·
  프레임별 스케일 후보 생성
- `pose_motion.scale` — 안정적인 단일 프레임을 골라 신체 비율로 미터 스케일
  (m/pixel) 산출
- `pose_motion.kinematics` — 저역통과 필터링, 미분, 픽셀→미터 변환
- `pose_motion.pipeline` — 세 단계를 파일 기반으로 연결
- `pose_motion.cli` — 명령줄 인터페이스 (`run` / `extract` / `scale` / `analyze`)

기존 네 스크립트(`detection_dataset.py`, `scale_discover.py`, `filter.py`,
`vel_acc_calculation_pipeline.py`)는 CLI로 넘겨주는 호환용 실행 파일로
유지됩니다.

## 작동 원리

### 1. 포즈 추출 (`extraction.py`)

- 모든 프레임에 `yolo11n-pose.pt`를 실행해 17개 COCO 키포인트(x, y, conf)를 얻음.
- 시간은 영상의 FPS로부터 계산: `time = frame_index / fps`.
- 세 가지 표를 생성:
  - **전체 키포인트** — 프레임별 모든 관절의 x/y/신뢰도.
  - **엉덩이 위치** — 중앙 엉덩이 `(왼쪽 + 오른쪽) / 2`, 양쪽 엉덩이 신뢰도가
    모두 `confidence_threshold`(기본 0.5) 이상인 프레임만 저장.
  - **스케일 후보** — 프레임별 어깨중점→발목중점 픽셀 길이, 어깨·발목 4개
    키포인트가 모두 임계값을 통과할 때만 저장.

엉덩이 중앙점의 수직 좌표는 신체 무게중심의 수직 운동을 대리하는 신호로
사용합니다.

### 2. 미터 스케일 추정 (`scale.py`)

단안 카메라는 픽셀만 제공하므로, 미터를 복원하려면 실제 길이를 아는 기준이
필요합니다. 여기서는 신체 자체가 그 기준입니다:

```
어깨-발목 실제길이(m) = 키(m) × 어깨-발목 비율        # 1.84 × 0.867 ≈ 1.595 m
스케일(m/pixel)      = 어깨-발목 실제길이 / 어깨-발목 픽셀길이
```

모든 프레임이 좋은 기준자는 아닙니다 — 자세가 굽거나, 가려지거나, 원근으로
짧아지면 신체 길이가 왜곡됩니다. 그래서 프레임마다 점수를 매겨 가장 좋은 단일
프레임을 선택합니다:

```
점수 =  time_weight   · time_score                      # 후반부 프레임 선호 (가중치 3.0)
      + length_weight · normalized(어깨-발목 픽셀)       # 신체가 가장 펴진 프레임 (가중치 2.0)
      − ratio_weight  · normalized(ratio_variation)     # 비율이 시간적으로 안정된 프레임 (가중치 1.0)
```

- `time_score`는 영상 전체에서 0→1로 선형 증가.
- `ratio_variation`은 세 관절 비율(어깨–엉덩이, 엉덩이–발목, 어깨–무릎을 각각
  어깨–발목 길이로 나눈 값)의 이동 표준편차(윈도우 30). 값이 작을수록 투영된
  신체 비율이 안정적임을 의미.

선택된 프레임의 스케일(`best_scale`)을 영상 전체에 적용합니다.

### 3. 운동학 계산 (`kinematics.py`)

미분은 포즈 추정의 미세한 떨림(jitter)을 증폭시키므로, 각 단계마다 위상 왜곡이
없는 Butterworth 저역통과 필터(`filtfilt`, 4차)를 적용합니다. 실제 몸동작은
저주파, 떨림은 고주파에 존재합니다.

1. 샘플링 주파수 `sampling_hz = 1 / mean(Δt)`.
2. 엉덩이 위치를 저역통과 필터링 (컷오프 5 Hz).
3. 미분 → 속도, 다시 저역통과 (컷오프 10 Hz).
4. 미분 → 가속도, 다시 저역통과 (컷오프 8 Hz).
5. 영상 y축은 아래로 증가하므로, 물리적 '위'가 양수가 되도록 부호를 뒤집음
   (`invert_vertical_axis`, 기본 켜짐).
6. 필터링된 픽셀 단위 속도·가속도에 `scale`을 곱해 **m/s, m/s²**로 변환.

## 출력 파일

`--output-dir`에 저장됩니다:

| 파일 | 내용 | 단위 |
| --- | --- | --- |
| `all_keypoints_video.csv` | 프레임별 전체 키포인트 x/y/conf | 픽셀 |
| `hip_positions_video.csv` | 유효 프레임의 엉덩이 중앙점 | 픽셀 |
| `scale_factors.csv` | 프레임별 스케일 후보 | m/pixel |
| `selected_scale.csv` | 선택된 프레임 + `best_scale` | m/pixel |
| `video_velocity.csv` | `video_velocity_m_s` | **m/s** |
| `video_acceleration.csv` | `video_acceleration` | **m/s²** |
| `hip_acceleration.csv` | 위치 + 속도·가속도를 픽셀·미터 컬럼 *양쪽*으로 | 픽셀 & 미터 |

> **`--show-plot` 주의.** 화면에 뜨는 그래프는 **픽셀 단위**(`velocity_pixel_s`,
> `acceleration_pixel_s2`)로 그려집니다 — 스케일을 곱하기 *전* 신호를
> 보여주는 것이지 최종 미터 결과가 아닙니다. 미터값은 CSV의 `*_m_s` 컬럼에만
> 있습니다. 그래프에서 미터값을 읽으면 안 됩니다.

## 최종 결과물

최종 산출물은 영상 프레임 속도로 샘플링된 두 개의 시계열입니다:

- **엉덩이 중앙점 수직 속도** `video_velocity_m_s` (m/s)
- **엉덩이 중앙점 수직 가속도** `video_acceleration` (m/s²)

둘은 같은 `time` 컬럼을 공유하므로, 각 행은 한 프레임에서 신체 수직 무게중심의
실제 속도·가속도를 나타냅니다. 부호를 뒤집은 뒤에는 **양수 = 위로 이동/가속,
음수 = 아래로 이동/가속**이며, 빠르게 주저앉는 동작은 큰 음의 속도와 뒤이은
날카로운 가속도 스파이크로 나타납니다.

실제로 동봉된 `yaxis_test_2_second_squat.mov`(13.9초, 813프레임)에서는 최대
속도 약 **1.1 m/s**, 최대 가속도 약 **4.6 m/s²**가 나옵니다 — 스쿼트 동작에
물리적으로 타당한 크기이며, 미터로 변환하는 이유가 바로 이것입니다: 이제
숫자가 특정 영상의 픽셀 기하에 묶이지 않고 카메라·거리·피험자에 걸쳐 서로
비교 가능해집니다.

이 미터 단위 속도·가속도 신호는 이후 낙상 감지 로직(예: 속도·가속도 임계값)의
입력으로 쓰이도록 설계된 것으로, 물리 단위 덕분에 임계값이 카메라에 종속되지
않고 이식 가능해집니다.

## 설치

```bash
python -m pip install -e .
```

이 프로젝트에서 사용한 `falldetection` Conda 환경에는 YOLO 실행에 필요한
`ultralytics`와 `opencv-python`이 설치되어 있습니다.

```bash
conda activate falldetection
python -m pip install -e .
```

## 실행

전체 파이프라인(추출 → 스케일 → 분석):

```bash
conda run -n falldetection python -m pose_motion run \
  yaxis_test_2_second_squat.mov \
  --height 1.84 \
  --shoulder-ankle-ratio 0.867 \
  --output-dir 0613_codex_integrate
```

속도·가속도 그래프(픽셀 단위)를 표시하려면 `--show-plot`을 추가합니다.

그래프까지 한 번에 보는 전체 파이프라인 명령:

```bash
conda run -n falldetection python -m pose_motion run \
  yaxis_test_2_second_squat.mov \
  --height 1.84 \
  --shoulder-ankle-ratio 0.867 \
  --output-dir 0613_codex_integrate \
  --show-plot
```

`--show-plot`을 켜면 창 세 개가 열립니다:

1. **통합** (3행) — 위치/속도/가속도, 원본 + 파생 + 필터 결과를 겹쳐서 표시
2. **Raw** (2행, 4:3 비율) — 필터링 전 노이즈 많은 속도 + 가속도만
3. **Filtered** (2행, 4:3 비율) — 필터링 후 깔끔한 속도 + 가속도만

레거시 스크립트 진입점도 같은 옵션으로 동작합니다
(`pose_motion run`으로 포워딩):

```bash
conda run -n falldetection python vel_acc_calculation_pipeline.py \
  yaxis_test_2_second_squat.mov \
  --height 1.84 \
  --shoulder-ankle-ratio 0.867 \
  --output-dir 0613_codex_integrate \
  --show-plot
```

단계별 실행:

```bash
conda run -n falldetection python -m pose_motion extract input.mov \
  --output-dir 0613_codex_integrate

conda run -n falldetection python -m pose_motion scale \
  --keypoints 0613_codex_integrate/all_keypoints_video.csv \
  --output 0613_codex_integrate/selected_scale.csv

conda run -n falldetection python -m pose_motion analyze \
  --hips 0613_codex_integrate/hip_positions_video.csv \
  --scale 0613_codex_integrate/selected_scale.csv \
  --output-dir 0613_codex_integrate
```

전체 설정 옵션은 `python -m pose_motion <command> --help`로 확인합니다.

### 주요 옵션 (기본값)

| 옵션 | 기본값 | 의미 |
| --- | --- | --- |
| `--height` | 1.84 | 피험자 키(m) — 미터 스케일을 결정 |
| `--shoulder-ankle-ratio` | 0.867 | 키 대비 어깨-발목 길이 비율 |
| `--confidence` | 0.5 | 프레임을 유지할 최소 키포인트 신뢰도 |
| `--scale-window` | 30 | 자세 안정성 점수 계산용 이동 윈도우 |
| `--position-cutoff` | 5.0 | Hz, 위치 저역통과 |
| `--velocity-cutoff` | 10.0 | Hz, 속도 저역통과 |
| `--acceleration-cutoff` | 8.0 | Hz, 가속도 저역통과 |
| `--filter-order` | 4 | Butterworth 차수 |
| `--keep-image-axis` | 꺼짐 | 영상 y-아래 축 유지(부호 뒤집기 생략) |

> 최종 **단위**는 항상 미터지만, 절대값의 정확도는 `--height`와
> `--shoulder-ankle-ratio`가 실제 피험자와 얼마나 일치하는가에 달려 있습니다.
