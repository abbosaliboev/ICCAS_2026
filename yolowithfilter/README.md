# Pose Motion Analysis

YOLO pose keypoints from a video are converted into a body scale, vertical
mid-hip velocity, and acceleration.

## Structure

- `pose_motion.extraction`: video pose extraction
- `pose_motion.scale`: stable-frame scale estimation
- `pose_motion.kinematics`: filtering, velocity, and acceleration
- `pose_motion.pipeline`: file-based pipeline orchestration
- `pose_motion.cli`: command-line interface

The original four scripts remain as thin compatibility entry points.

## Install

```bash
python -m pip install -e .
```

## Run

Run every stage:

```bash
python -m pose_motion run yaxis_test_2_second_squat.mov \
  --height 1.84 \
  --shoulder-ankle-ratio 0.867 \
  --output-dir results
```

Run individual stages:

```bash
python -m pose_motion extract input.mov --output-dir results
python -m pose_motion scale --keypoints results/all_keypoints_video.csv \
  --output results/selected_scale.csv
python -m pose_motion analyze \
  --hips results/hip_positions_video.csv \
  --scale results/selected_scale.csv \
  --output-dir results
```

Use `python -m pose_motion <command> --help` for all configuration options.

---

# 포즈 기반 동작 분석

영상에서 YOLO 포즈 키포인트를 추출하고, 신체 스케일을 추정하여 엉덩이
중앙점의 수직 속도와 가속도를 계산합니다.

## 구조

- `pose_motion.extraction`: 영상에서 YOLO 포즈 데이터 추출
- `pose_motion.scale`: 안정적인 프레임을 선택하여 신체 스케일 추정
- `pose_motion.kinematics`: 필터링 및 속도·가속도 계산
- `pose_motion.pipeline`: 전체 분석 단계 실행 및 결과 파일 저장
- `pose_motion.cli`: 명령줄 인터페이스

기존의 네 스크립트는 이전 실행 방식을 지원하기 위한 호환용 실행 파일로
유지됩니다.

## 설치

현재 프로젝트를 Python 패키지로 설치합니다.

```bash
python -m pip install -e .
```

이 프로젝트에서 사용한 `falldetection` Conda 환경에는 YOLO 실행에 필요한
`ultralytics`와 `opencv-python`이 설치되어 있습니다.

```bash
conda activate falldetection
python -m pip install -e .
```

## 전체 파이프라인 실행

YOLO 포즈 추출, 스케일 추정, 속도·가속도 계산을 순서대로 실행합니다.

```bash
conda run -n falldetection python -m pose_motion run \
  yaxis_test_2_second_squat.mov \
  --height 1.84 \
  --shoulder-ankle-ratio 0.867 \
  --output-dir 0613_codex_integrate
```

속도·가속도 그래프를 표시하려면 `--show-plot` 옵션을 추가합니다.

```bash
conda run -n falldetection python -m pose_motion run \
  yaxis_test_2_second_squat.mov \
  --output-dir 0613_codex_integrate \
  --show-plot
```

## 단계별 실행

각 분석 단계를 개별적으로 실행할 수도 있습니다.

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

전체 설정 옵션은 다음 명령으로 확인할 수 있습니다.

```bash
python -m pose_motion <command> --help
```
