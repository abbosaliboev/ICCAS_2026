# Limitations / 한계점 / Cheklovlar

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

---

<a name="english"></a>
# 🇺🇸 English

## 1. Dataset limitations

### 1-1. Single dataset (UP-Fall only)
The model is trained and evaluated exclusively on the UP-Fall Detection Dataset (controlled lab environment, Guadalajara, Mexico). Real-world performance may differ due to:
- Different camera angles, heights, and placements
- Different room sizes and backgrounds
- Different lighting conditions (UP-Fall uses consistent indoor lighting)
- Different clothing and body types not seen in training

### 1-2. Subject count
Current best model trained on Subjects 1–4 (4 of 17). **LOSO evaluation across all 17 subjects has not been performed.** Published F1=0.955 is subject-dependent, not cross-subject generalization.

| Evaluation type | Status | Expected F1 |
|---|---|---|
| Subject-dependent (1–4) | ✅ done | **0.955** |
| Subject-dependent (1–17) | ⬜ pending | ~0.95+ |
| **LOSO (cross-subject)** | ⬜ pending | **~0.75–0.88** |

> The LOSO result is the standard metric for real-world generalization and is required for the paper.

### 1-3. Activity coverage
UP-Fall has 11 activities (5 falls, 6 non-falls). Real-world falls include additional types not covered:
- Falling in the dark / low light
- Falling onto furniture (partial fall)
- Gradual slide down a wall
- Falls with assistive devices (walker, cane)
- Multiple people in frame

---

## 2. Sensing limitations

### 2-1. Single monocular camera
No depth information. Falls perpendicular to the camera axis (person falls toward or away from camera) may produce ambiguous 2D skeleton projections.

### 2-2. Occlusion
If the person is partially or fully occluded (by furniture, walls, or another person), YOLO may fail to detect keypoints. The zero-frame fill interpolation partially mitigates this, but extended occlusion (>10–15 consecutive frames) may cause incorrect sequences.

### 2-3. Single person assumption
The pipeline always selects the most confident detected person. Multi-person scenarios (caregiver + elderly, visitor present) will only track one person and may select the wrong one.

### 2-4. Privacy constraint
Camera placement in bathrooms and restrooms is not acceptable — these are high-risk fall zones that remain unmonitored.

---

## 3. Model limitations

### 3-1. No baseline comparison yet
LSTM and TCN baselines have not been implemented. The improvement over simpler methods is not yet quantified.

### 3-2. Physics filter threshold sensitivity
Thresholds (`vel_threshold`, `acc_threshold`) are tuned on the validation set of the current training split. They may overfit to UP-Fall motion patterns and not generalize to different frame rates or camera heights.

### 3-3. Fixed window size
The 30-frame (~1.6 s) window is fixed. Very fast falls (<1 second) may be split across two windows, reducing detection confidence in both.

### 3-4. Temporal latency
Minimum detection latency = one full window = 1.6 seconds. Alert is triggered only after `--confirm=3` consecutive positive windows (~4.8 s after fall onset by default). Early alert requires reducing `--confirm` at the cost of more false positives.

---

## 4. Deployment limitations

### 4-1. Jetson-specific constraints
- TensorRT engine is device-specific: an engine built on one Jetson model will show a warning ("engine plan file across different models") on another.
- TRT + PyTorch CUDA allocator conflict prevents running both on GPU simultaneously; ST-GCN must run on CPU when TRT is active.

### 4-2. RTSP reliability
RTSP streams can disconnect due to network issues. The current reconnect logic retries every 2–3 seconds, but fall events during reconnection are missed.

### 4-3. Night / low light
YOLO keypoint detection accuracy degrades significantly in low light. An IR camera or supplemental lighting is needed for 24-hour operation.

---

## 5. What is needed before publication

- [ ] LOSO evaluation across all 17 subjects
- [ ] LSTM and TCN baseline implementations
- [ ] Per-activity F1 breakdown (which fall types are detected well/poorly)
- [ ] Multi-lighting condition test
- [ ] False positive rate in continuous real-world deployment (not just UP-Fall test set)

---

<a name="korean"></a>
# 🇰🇷 한국어

## 1. 데이터셋 한계

### 1-1. 단일 데이터셋 (UP-Fall만)
모델은 통제된 실험실 환경의 UP-Fall 데이터셋에서만 학습·평가됩니다. 실제 환경에서는 다음과 같은 차이로 성능이 달라질 수 있습니다:
- 다른 카메라 각도, 높이, 설치 위치
- 다른 방 크기와 배경
- 다른 조명 조건
- 학습에 없던 체형과 의상

### 1-2. 피험자 수
현재 최고 모델은 Subject 1–4 (17명 중 4명)만 학습. **전체 17명 대상 LOSO 평가 미완료.** F1=0.955은 subject-dependent 결과로, 교차 피험자 일반화 성능이 아닙니다.

| 평가 유형 | 상태 | 예상 F1 |
|---|---|---|
| Subject-dependent (1–4) | ✅ 완료 | **0.955** |
| Subject-dependent (1–17) | ⬜ 미완 | ~0.95+ |
| **LOSO (교차 피험자)** | ⬜ 미완 | **~0.75–0.88** |

### 1-3. Activity 범위
UP-Fall의 11개 activity 외 실제 낙상 유형 미포함:
- 어두운 환경에서의 낙상
- 가구에 걸쳐지는 낙상
- 보행 보조기 사용자의 낙상
- 여러 명이 화면에 있는 경우

---

## 2. 센싱 한계

### 2-1. 단안 카메라 (깊이 정보 없음)
카메라 축 방향으로 넘어지는 경우 2D 스켈레톤이 모호해질 수 있습니다.

### 2-2. 가림 (Occlusion)
가구, 벽, 다른 사람에 의해 가려지면 YOLO가 키포인트를 놓칠 수 있습니다. Zero-frame fill로 일부 보완되지만, 장시간 가림(>10–15프레임)은 오작동을 유발할 수 있습니다.

### 2-3. 단일 인물 가정
가장 높은 신뢰도의 인물 하나만 추적합니다. 간병인 + 노인이 동시에 있으면 잘못된 인물을 추적할 수 있습니다.

### 2-4. 프라이버시 제약
욕실·화장실은 카메라 설치 불가 → 낙상 위험 구역임에도 감시 불가.

---

## 3. 모델 한계

### 3-1. Baseline 비교 미완료
LSTM, TCN Baseline이 구현되지 않아 성능 향상 정도를 수치로 비교할 수 없습니다.

### 3-2. Physics filter 임계값 과적합 가능성
임계값이 현재 validation set에 맞춰 조정됨 — 다른 카메라 높이나 프레임 속도에서 일반화 여부 미확인.

### 3-3. 고정 윈도우 크기
30프레임(~1.6초) 고정. 1초 미만의 빠른 낙상이 두 윈도우에 분할되어 감지 신뢰도가 낮아질 수 있습니다.

### 3-4. 시간 지연
최소 감지 지연 = 1 윈도우 = 1.6초. 기본값 `--confirm=3`이면 낙상 발생 후 약 4.8초 뒤 알림.

---

## 4. 배포 한계

### 4-1. Jetson 특화 제약
TRT 엔진은 특정 디바이스에서 생성된 것으로, 다른 Jetson 모델에서 경고 발생. TRT + PyTorch CUDA 동시 사용 불가 → ST-GCN은 CPU에서 실행.

### 4-2. RTSP 안정성
네트워크 문제로 RTSP가 끊기면 재연결 시도 중 낙상 이벤트를 놓칠 수 있습니다.

### 4-3. 야간 / 저조도
저조도에서 YOLO 키포인트 감지 정확도가 크게 저하됩니다. 24시간 운영을 위해 IR 카메라 또는 보조 조명이 필요합니다.

---

## 5. 논문 제출 전 필요 작업

- [ ] 전체 17명 대상 LOSO 평가
- [ ] LSTM, TCN Baseline 구현
- [ ] Activity별 F1 분석
- [ ] 다양한 조명 조건 테스트
- [ ] 실제 환경에서의 false positive rate 측정

---

<a name="uzbek"></a>
# 🇺🇿 O'zbekcha

## 1. Dataset cheklovlari

### 1-1. Bitta dataset (faqat UP-Fall)
Model faqat UP-Fall datasetida (nazorat ostidagi laboratoriya muhiti) o'rgatilgan va baholangan. Haqiqiy muhitda farqlar bo'lishi mumkin:
- Boshqa kamera burchagi, balandligi va joylashuvi
- Boshqa xona o'lchamlari va fonlar
- Boshqa yoritish sharoitlari
- Treningda ko'rilmagan tana tuzilishi va kiyimlar

### 1-2. Subject soni
Hozirgi eng yaxshi model Subject 1–4 (17 tadan 4 tasi) da o'rgatilgan. **Barcha 17 subject bo'yicha LOSO baholash amalga oshirilmagan.** F1=0.955 subject-dependent natija, cross-subject umumlashtiruv emas.

| Baholash turi | Holat | Kutilgan F1 |
|---|---|---|
| Subject-dependent (1–4) | ✅ bajarildi | **0.955** |
| Subject-dependent (1–17) | ⬜ kutilmoqda | ~0.95+ |
| **LOSO (cross-subject)** | ⬜ kutilmoqda | **~0.75–0.88** |

### 1-3. Activity qamrovi
UP-Fall ning 11 ta activitysidan tashqari haqiqiy yiqilish turlari qamrab olinmagan:
- Qorong'uda yiqilish
- Mebel ustiga yiqilish
- Yurish vositasi (tayoq, yurish ramkasi) ishlatuvchi bemorlar
- Kadrda bir nechta odam bo'lgan holat

---

## 2. Sensor cheklovlari

### 2-1. Bitta monokular kamera (chuqurlik ma'lumoti yo'q)
Kamera o'qi bo'ylab yiqilish (kameraga qarab yoki undan uzoqlashib) 2D skeletda noaniq ko'rinishi mumkin.

### 2-2. Yopilish (Occlusion)
Mebel, devor yoki boshqa odam tomonidan yopilsa YOLO keypointlarni aniqlay olmaydi. Zero-frame fill qisman hal qiladi, lekin uzoq yopilish (>10–15 kadr) xato ishlarishiga olib kelishi mumkin.

### 2-3. Bitta odam taxminoti
Faqat eng ishonchli bir odamni kuzatadi. Parvarish beruvchi + keksa bir kadrda bo'lsa noto'g'ri odamni kuzatishi mumkin.

### 2-4. Maxfiylik cheklovi
Hammom va hojatxonaga kamera o'rnatish mumkin emas — yuqori xavfli zonalar nazorat qilinmaydi.

---

## 3. Model cheklovlari

### 3-1. Baseline taqqosi yo'q hali
LSTM va TCN baselineslar amalga oshirilmagan. Oddiy modellardan qanchalik yaxshiroq ishlashi raqamda ko'rsatilmagan.

### 3-2. Physics filter threshold sezgirligi
Thresholdlar joriy validation setga moslashtirilgan — boshqa kamera balandligi yoki frame rate da umumlashtiruv tekshirilmagan.

### 3-3. Qattiq oyna o'lchami
30-kadr (~1.6 soniya) qattiq. 1 soniyadan tez yiqilish ikki oynaga bo'linib, ikkisida ham ishonch past bo'lishi mumkin.

### 3-4. Vaqt kechikishi
Minimal aniqlash kechikishi = 1 oyna = 1.6 soniya. Standart `--confirm=3` bilan yiqilishdan ~4.8 soniya keyin ogohlantirish yuboriladi.

---

## 4. Joylashtirishdagi cheklovlar

### 4-1. Jetson ga xos cheklovlar
TRT engine qurilmaga xos: boshqa Jetson modelida ogohlantirish chiqadi. TRT + PyTorch CUDA bir vaqtda GPU da ishlay olmaydi → ST-GCN CPU da ishlaydi.

### 4-2. RTSP ishonchliligi
Tarmoq muammosida RTSP uzilib, qayta ulanish vaqtida yiqilish hodisasi o'tkazib yuborilishi mumkin.

### 4-3. Tun / past yorug'lik
Past yorug'likda YOLO keypoint aniqlash aniqligi sezilarli darajada tushadi. 24 soatlik ishlash uchun IR kamera yoki qo'shimcha yorug'lik kerak.

---

## 5. Nashr oldidan kerakli ishlar

- [ ] Barcha 17 subject bo'yicha LOSO baholash
- [ ] LSTM va TCN Baseline amalga oshirish
- [ ] Activity bo'yicha F1 tahlil
- [ ] Turli yoritish sharoitlarida sinov
- [ ] Haqiqiy muhitda false positive darajasini o'lchash
