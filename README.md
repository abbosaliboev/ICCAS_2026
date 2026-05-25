# MobiCare
### Edge AI-Based Real-Time Fall Detection and Alert System for Elderly People Living Alone
### 독거 노인을 위한 엣지 AI 기반 실시간 낙상 감지 및 알림 시스템

![MobiCare](./Docs/Images/MobiCare.png)

> **Language / 언어 선택**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)

---

## 📄 Documents

| Document | Link |
|----------|------|
| Abstract (Markdown) | [Docs/Poster/abstract.md](./Docs/Poster/abstract.md) |
| Poster (PDF) | [Docs/Poster/4조 초록.pdf](./Docs/Poster/4조%20초록.pdf) |

---

<a name="english"></a>
# 🇺🇸 English

## 1. What Service?

### Core Message
> **"Stop it before it happens. Detect it the moment it does. Bring them back after."**

---

### Who Is It For?

Korea and France have both entered **super-aged societies** — people aged 65 and older now make up over 20% of the total population. In France, about **30% of people aged 65+** experience a fall every year. In Korea, falls account for the **highest proportion** of all injury causes.

MobiCare primarily targets **elderly people living alone**, where no caregiver is present to respond immediately after a fall.

| Target | Scale | Core Risk |
|--------|-------|-----------|
| Elderly living alone (65+) | ~2 million in Korea | Left unattended after a fall — no one to respond |
| Nursing hospital patients | High-risk environment | Repeated falls, staff cannot monitor all patients |
| Senior welfare facility residents | Institutional setting | Falls during nighttime or unsupervised hours |

---

### Where Does It Work?

```
All indoor spaces:
✅ Living room / Hallway / Bedroom / Kitchen
✅ Stairs (the #1 location for fall accidents)
✅ Yard / Garden / Balcony
❌ Bathroom / Restroom (privacy)
```

> Top 3 fall risk zones: **living room, bathroom surroundings, bedroom** — each with different characteristics and risk patterns.

---

### How It Works — 3 Stages

```
① PREVENT
   Daily "Frozen!" game — 5 minutes
   → AI quietly measures balance ability
   → "Balance declined 15% this week" → early warning sent to family

② DETECT
   24/7 camera + audio analysis
   → Fall detected instantly
   → Family app notification + SMS within 3 seconds

③ REHABILITATE
   Personalized exercise program after a fall
   → YOLOv11 analyzes posture and movement in real time
   → Weekly rehabilitation report → sent automatically to hospital
```

---

## 2. What Product?

### Limitations of Existing Solutions

| Existing Product | Limitation |
|-----------------|------------|
| Smartwatch fall detection | Detects **after** the fall. No prevention. High resistance to wear among elderly |
| Home CCTV | Recording only. No AI analysis. No alerts |
| Hospital rehabilitation programs | 1–2 visits per week. Requires travel. No daily monitoring |
| Fall detection mats | Detects only one spot. Not portable. No rehab function |

> All existing wearable sensor-based systems require users to wear a device at all times — uncomfortable, and they cannot track full-body movement since they only measure one body part.

### What MobiCare Improves

```
Before:   fall happens → detected
MobiCare: before fall → predict → prevent
          fall happens → instant detection → alert
          after fall   → rehabilitation → recovery
```

**Only two things needed:**
- Regular camera (webcam or IP camera)
- Smartphone (family app)

No extra sensors, wearables, or special equipment required.

---

### Core Technology

```
📷 Single Camera Input
    ↓
Edge AI Device (Lightweight Model)
    ↓
YOLOv11 Pose Estimation
→ Real-time tracking of 17 body joints
→ Fall pattern detection
→ Balance Score quantification
    ↓
Audio Analysis Model
→ Crying / "Help!" / Impact sound detection
    ↓
Fall Decision Logic
→ Minimize false alarms
   (distinguish sitting down vs. actual fall)
    ↓
Alert Service (Push / SMS / KakaoTalk)
    ↓
Family app + Dashboard
```

> **Edge AI**: the model runs directly on an edge device — low latency, no dependency on cloud connection, privacy-safe.

---

### Game: "Frozen!" — Prevention as a Game

> **Balance training from the clinic — now at home, every day, and fun.**

- Simple game: when the music stops, freeze in place
- YOLOv11 measures stability of the frozen pose in real time
- **Anyone in the world understands in 5 seconds** — no language barrier
- Ranking system for ongoing motivation

```
Ranking structure:
├── Personal ranking (last week me vs. this week me)
├── Local ranking (how do I rank in my neighborhood?)
└── Age group ranking (where do I rank among people in their 70s?)
```

---

#### Game Interaction — Two Options Under Review

> **One will be chosen, or decided based on implementation difficulty.**

**Option A — Free Movement Mode**
```
Music plays → user moves freely
Music stops → freeze in place
AI measures only stability of the frozen pose
→ Any pose is fine — score is based on how still you are
```
- Pros: easy to implement, anyone can do it instantly, no instructions needed
- Cons: hard to standardize as a rehabilitation exercise

**Option B — Guided Pose Mode**
```
Music plays → target pose (template) shown on screen
User follows the pose
Music stops → freeze in that pose
AI measures pose accuracy + stability simultaneously
```
- Pros: clear rehabilitation effect, posture correction possible
- Cons: complex to implement (pose matching logic), difficult for users who struggle to follow instructions

**Current decision:**
```
If template is too complex → Option A (free movement)
If feasible → Option B (guided) or both modes combined
```

---

#### Personalized Game Mode

> **Identify who the user is first. Then set game conditions automatically.**

On first launch, the user sets up a profile.  
Game difficulty, pose type, and scoring criteria are **automatically personalized**.

```
User profile setup
├── Age / Gender
├── Current condition:
│   ├── General elderly (balance maintenance)
│   ├── Stroke rehabilitation patient
│   ├── Dementia patient
│   ├── Post-orthopedic surgery recovery
│   └── Person with physical disability (wheelchair / walking aid)
└── Rehabilitation goal (balance / fall prevention / strength recovery)
```

**Game parameters by user type:**

| User Type | Music Tempo | Freeze Duration | Tracked Area | Sway Tolerance |
|-----------|-------------|-----------------|--------------|----------------|
| General elderly | Normal | 5 sec | Full body | Normal |
| Stroke patient | Slow | 8 sec | Upper body focus | Wide |
| Dementia patient | Slow + simple | 10 sec | Full body (simple poses) | Wide |
| Post-surgery recovery | Very slow | 10 sec | Minimize lower body strain | Wide |
| Physical disability | Normal | 5 sec | Seated pose standard | Upper body only |

**Automatic difficulty adjustment over time:**
```
Week 1: easy poses, slow music, long freeze time
       ↓ if Balance Score improves
Week 2: automatically upgraded to slightly harder poses
       ↓ if no improvement
       → alert sent to family
```

---

## 3. How Do We Prove It Works?

### Measurable Metrics (Data-Driven)

**① Balance Score**
```
Measurement method:
YOLOv11 → tracks Center of Mass (CoM)
→ measures sway range per second (cm)
→ quantified as 0–100 score

Clinical reference: validated against Berg Balance Scale (BBS)
```

**② Fall Detection Accuracy**
```
Precision / Recall / F1-Score
Target: Precision 90%+, Recall 95%+
(minimize false alarms, never miss a real fall)

Baseline: standard video-based action recognition model
```

**③ Rehabilitation Progress**
```
Weekly Balance Score change rate
Exercise consistency (consecutive days participated)
Reduction in hospital visit frequency
```

**④ Alert Response Time**
```
Fall event → family notification received:
Target: within 3 seconds
```

---

### Data Collection Types

```
Skeleton data:
  - 17 joints (x, y, confidence score)
  - 30 FPS real-time tracking

Audio data:
  - MFCC features
  - 16kHz sampling rate
  - Classification: crying / impact sound / "Help!"

Balance Score:
  - CoM displacement (cm/s)
  - Delta from session start to end

Event log:
  - timestamp, room ID, alert type, response time
```

> **Dataset strategy:** Initial model validation using Le2i Fall Detection Dataset + UR Fall Detection Dataset.  
> Followed by small-scale in-home data collection in real environments.

---

### Data Visualization — Dashboard

```
Family app:
├── Real-time alert (when fall occurs)
├── Today's activity summary
└── Weekly health trend graph

Hospital / Doctor view:
├── Weekly Balance Score change
├── Exercise participation rate
├── Fall history log
└── AI-generated rehabilitation report (Gemini AI)

Danger zone heatmap:
└── Top 3 risk zones in the home — living room, bedroom, hallway
    (each zone has different fall characteristics → different response)
```

---

## 4. Expected Impact

### Individual Level

```
Before MobiCare:
fall → no one knows → found hours later → fracture → hospitalization → social isolation

After MobiCare:
balance decline detected → rehab exercise → fall prevented → mobility maintained
                    OR
fall detected instantly → family notified in 3 seconds → rapid response
```

- Fall rate reduction (research basis: **30–40% reduction** with consistent rehab exercise)
- Time to discovery after a fall: average 1 hour → **3 seconds**
- Rehabilitation participation: hospital-based 1–2x/week → **daily possible**

---

### Social Level

```
Aging society + rural community decline
        ↓
Growing number of elderly living alone
        ↓
MobiCare
        ↓
① Reduced medical costs (fall prevention = fewer hospitalizations)
② Reduced psychological burden on families
③ Extended period of independent living for elderly
④ Applicable to nursing hospitals and senior welfare facilities
```

> Based on Korea's National Health Insurance Service data,  
> fall-related hospitalization costs are estimated at over **1 trillion KRW per year**.  
> MobiCare can structurally reduce a portion of this cost.

---

### The Meaning in Terms of AI Mobility

> *"Mobility is not just about walking.  
> It's about participating in society, staying connected to family, and living with dignity.  
> MobiCare protects that ability with AI."*

**MobiCare is not a fall detection app.**  
**It is a platform that uses Edge AI to protect the lives of elderly people living alone.**

---

## Summary

| Question | Answer |
|----------|--------|
| **What?** | Edge AI fall detection + balance game + alert system |
| **Who?** | Elderly living alone, nursing hospital & welfare facility residents |
| **When?** | 24/7 — whenever the elderly person is without a caregiver |
| **Where?** | Living room, bedroom, stairs, hallway |
| **Why?** | Falls among the elderly living alone go unnoticed for hours |
| **How?** | Single camera + lightweight Edge AI + instant alert (SMS/Push) |

---

---

<a name="korean"></a>
# 🇰🇷 한국어

## 1. 어떤 서비스를?

### 핵심 한 줄
> **"넘어지기 전에 막고, 넘어지면 즉시 알리고, 넘어진 후엔 다시 일으킨다."**

---

### 누구를 위한 서비스인가?

한국과 프랑스는 모두 **초고령사회**에 진입했습니다 — 65세 이상 인구가 전체의 20% 이상입니다.  
프랑스에서는 65세 이상 노인의 약 **30%**가 매년 낙상을 경험하며,  
한국에서도 낙상은 전체 손상 원인 중 **가장 높은 비중**을 차지합니다.

MobiCare는 **독거 노인**을 주요 대상으로 합니다 — 낙상 후 즉각적인 확인이 어려운 환경에 있는 분들입니다.

| 대상 | 규모 | 핵심 위험 |
|------|------|-----------|
| 독거 노인 (65세+) | 한국 약 200만 명 | 낙상 후 장시간 방치 — 즉각 대응 불가 |
| 요양병원 환자 | 고위험 환경 | 반복 낙상, 전체 환자 상시 감시 불가 |
| 노인복지시설 거주자 | 시설 환경 | 야간 또는 무감독 시간대 낙상 |

---

### 어떤 공간에서?

```
집 안 모든 공간:
✅ 거실 / 복도 / 침실 / 주방
✅ 계단 (낙상 사고 1위 장소)
✅ 마당 / 정원 / 발코니
❌ 욕실 / 화장실 (프라이버시)
```

> 낙상 위험 구역 Top 3: **거실, 욕실 주변, 침실** — 각 구역마다 낙상 특성과 대응 방식이 다릅니다.

---

### 서비스 방법 — 3단계

```
① PREVENT (예방)
   매일 "Frozen!" 게임 5분
   → AI가 균형 능력을 조용히 측정
   → "이번 주 균형 능력 15% 저하" → 가족에게 사전 경고

② DETECT (감지)
   24시간 카메라 + 음성 분석
   → 낙상 발생 즉시 감지
   → 3초 안에 가족 앱 알림 + 문자

③ REHABILITATE (재활)
   낙상 후 맞춤 운동 프로그램
   → YOLOv11이 자세와 동작을 실시간 분석
   → 주간 재활 리포트 → 병원 자동 전송
```

---

## 2. 어떤 제품으로?

### 기존 유사 제품의 한계

| 기존 제품 | 한계점 |
|-----------|--------|
| 스마트워치 낙상 감지 | **넘어진 후** 감지. 예방 불가. 고령자 착용 거부감 높음 |
| 가정용 CCTV | 단순 녹화만. AI 분석 없음. 알림 없음 |
| 병원 재활 프로그램 | 주 1~2회, 병원 방문 필수. 일상 모니터링 불가 |
| 기존 낙상 감지 매트 | 특정 위치만 감지. 이동 불가. 재활 기능 없음 |

> 기존 웨어러블 센서 방식은 사용자가 장치를 항상 착용해야 하며, 단일 부위 측정으로 전신 거동 파악이 불가합니다.

### MobiCare가 개선하는 것

```
기존:  넘어진 후 → 감지
MobiCare: 넘어지기 전 → 예측 → 예방
           넘어진 후  → 즉시 감지 → 알림
           넘어진 다음 → 재활 → 회복
```

**필요한 것은 단 두 가지:**
- 일반 카메라 (웹캠 또는 IP 카메라)
- 스마트폰 (가족용 앱)

추가 센서, 웨어러블, 특수 장비 — 전혀 필요 없습니다.

---

### 핵심 기술 구성

```
📷 단일 카메라 입력
    ↓
엣지 AI 디바이스 (경량화 모델)
    ↓
YOLOv11 Pose Estimation
→ 17개 신체 관절 실시간 추적
→ 낙상 패턴 감지
→ 균형 능력 정량화 (Balance Score)
    ↓
음성 분석 모델
→ 울음소리 / "도와주세요" / 충격음 감지
    ↓
낙상 판단 로직
→ 오탐(False Alarm) 최소화
   (앉는 동작 vs 실제 낙상 구별)
    ↓
알림 서비스 (푸시 / 문자 / 카카오톡)
    ↓
가족 앱 + 대시보드
```

> **엣지 AI**: 모델이 엣지 디바이스에서 직접 실행 — 낮은 지연시간, 클라우드 연결 불필요, 프라이버시 보호.

---

### 게임: "Frozen!" — 예방을 게임으로

> **치료실에서 하던 균형 훈련을 집에서, 매일, 재미있게.**

- 음악이 멈추면 그 자리에서 멈추는 단순한 게임
- YOLOv11이 멈춘 자세의 안정성을 실시간 측정
- **전 세계 누구나 5초 만에 이해 가능** — 언어 장벽 없음
- 랭킹 시스템으로 지속적 동기 부여

```
랭킹 구조:
├── 개인 랭킹 (지난 주 나 vs 이번 주 나)
├── 지역 랭킹 (우리 동네 몇 위?)
└── 연령대 랭킹 (70대 중 몇 위?)
```

---

#### 🔧 동작 방식 — 검토 중인 두 가지 방향

> **현재 둘 중 하나를 선택하거나, 구현 난이도에 따라 결정 예정.**

**Option A — 자유 동작 모드 (Free Movement)**
```
음악 재생 → 사용자가 자유롭게 움직임
음악 정지 → 그 자리에서 멈춤
AI가 멈춘 자세의 안정성(균형)만 측정
→ 어떤 자세든 상관없음, 얼마나 안 흔들리는지가 점수
```
- 장점: 구현 쉬움, 누구나 즉시 가능, 지시 불필요
- 단점: 재활 운동으로서의 효과 표준화 어려움

**Option B — 템플릿 동작 모드 (Guided Pose)**
```
음악 재생 → 화면에 목표 자세(템플릿) 표시
사용자가 그 자세를 따라 함
음악 정지 → 해당 자세로 멈춤
AI가 템플릿 자세와의 일치도 + 안정성 동시 측정
```
- 장점: 재활 운동 효과 명확, 자세 교정 가능
- 단점: 구현 복잡 (pose matching 로직 필요), 지시 따르기 어려운 사용자에게 불편

**현재 판단:**
```
템플릿 구현이 어려울 경우 → Option A (자유 동작)
여유가 있을 경우 → Option B (템플릿) 또는 두 모드 병행
```

---

#### 🎯 사용자 맞춤형 게임 — Personalized Mode

> **사용자가 누구인지 먼저 파악하고, 그에 맞는 게임 조건을 자동으로 설정한다.**

```
사용자 프로필 입력
├── 나이 / 성별
├── 현재 상태 선택:
│   ├── 일반 노인 (균형 유지 목적)
│   ├── 뇌졸중 재활 환자
│   ├── 치매 환자
│   ├── 정형외과 수술 후 회복
│   └── 지체 장애인 (휠체어 / 보행 보조기 사용)
└── 재활 목표 설정 (균형 유지 / 낙상 예방 / 근력 회복)
```

**조건별 게임 파라미터 변화:**

| 사용자 유형 | 음악 속도 | 멈춤 시간 | 측정 부위 | 허용 흔들림 |
|------------|----------|----------|----------|------------|
| 일반 노인 | 보통 | 5초 | 전신 | 보통 |
| 뇌졸중 환자 | 느림 | 8초 | 상체 집중 | 넓게 허용 |
| 치매 환자 | 느림 + 단순 | 10초 | 전신 (단순 자세) | 넓게 허용 |
| 수술 후 회복 | 매우 느림 | 10초 | 하체 부담 최소화 | 넓게 허용 |
| 지체 장애인 | 보통 | 5초 | 앉은 자세 기준 | 상체만 측정 |

**시간에 따라 자동 난이도 조정:**
```
1주차: 쉬운 자세, 느린 음악, 긴 멈춤 시간
      ↓ Balance Score 개선 감지 시
2주차: 조금 더 어려운 자세로 자동 업그레이드
      ↓ 개선 없을 시
      → 가족에게 알림
```

---

## 3. 개선했다는 걸 어떻게 증명하는가?

### 측정 가능한 지표 (Data-Driven)

**① Balance Score (균형 점수)**
```
측정 방법:
YOLOv11 → 신체 중심점(CoM) 추적
→ 시간당 흔들림 범위 (cm) 측정
→ 0~100점 정량화

임상 기준: Berg Balance Scale (BBS) 과 상관관계 검증
```

**② 낙상 감지 정확도**
```
Precision / Recall / F1-Score 측정
목표: Precision 90%+, Recall 95%+
(오탐은 줄이고, 실제 낙상은 놓치지 않는다)

Baseline: 기본 영상 학습 모델 (standard video-based action recognition)
```

**③ 재활 진행도**
```
주간 Balance Score 변화율
운동 지속률 (며칠 연속 참여했는가)
병원 방문 횟수 감소율
```

**④ 알림 응답 시간**
```
낙상 발생 → 가족 알림 수신까지:
목표: 3초 이내
```

---

### 데이터 수집 유형

```
Skeleton 데이터:
  - 17개 관절 (x, y, confidence score)
  - 30 FPS 실시간 추적

음성 데이터:
  - MFCC features
  - 16kHz sampling rate
  - 울음소리 / 충격음 / "도와주세요" 분류

Balance Score:
  - CoM displacement (cm/s)
  - 세션 시작 ~ 종료 변화량

이벤트 로그:
  - timestamp, room ID, alert type, response time
```

> **Dataset 전략:** Le2i Fall Detection Dataset + UR Fall Detection Dataset 기반으로  
> 초기 모델 검증. 이후 실제 가정 환경에서 자체 소규모 데이터 수집 예정.

---

### 데이터 시각화 — 대시보드

```
가족용 앱:
├── 실시간 알림 (낙상 발생 시)
├── 오늘의 활동 요약
└── 이번 주 건강 트렌드 그래프

병원/의사용:
├── 주간 Balance Score 변화
├── 운동 참여율
├── 낙상 발생 이력
└── AI 생성 재활 리포트 (Gemini AI)

위험 구역 히트맵:
└── 낙상 위험 Top 3 구역 — 거실, 침실, 복도
    (구역별 낙상 특성이 다름 → 구역별 대응 방안 제안)
```

---

## 4. 기대 효과는?

### 개인 차원

```
Before MobiCare:
낙상 → 아무도 모름 → 수 시간 후 발견 → 골절 → 입원 → 사회적 고립

After MobiCare:
균형 저하 감지 → 재활 운동 → 낙상 예방 → 모빌리티 유지
              또는
낙상 즉시 감지 → 3초 안에 가족에게 알림 → 빠른 대응
```

- 낙상 발생률 감소 (재활 운동 지속 시 연구 기준 **30~40% 감소** 가능)
- 낙상 후 발견 시간: 평균 1시간 → **3초**
- 재활 운동 참여율: 병원 방문 기반 주 1~2회 → **매일 가능**

---

### 사회적 차원

```
고령화사회 + 지역소멸
        ↓
독거 노인 증가
        ↓
MobiCare
        ↓
① 의료비 절감 (낙상 예방 = 입원 감소)
② 가족 심리적 부담 감소
③ 노인 자립 생활 기간 연장
④ 요양병원 / 노인복지시설 안전 시스템으로 확장 가능
```

> 한국 건강보험공단 기준, 낙상 관련 입원 치료비는  
> 연간 **약 1조 원** 이상으로 추정됩니다.  
> MobiCare는 이 비용의 일부를 구조적으로 줄일 수 있습니다.

---

### AI Mobility 관점에서의 의미

> *"모빌리티(이동 능력)는 단순히 걷는 것이 아닙니다.  
> 사회에 참여하고, 가족과 연결되고, 인간다운 삶을 사는 것입니다.  
> MobiCare는 엣지 AI로 그 능력을 지킵니다."*

**MobiCare는 낙상 감지 앱이 아닙니다.**  
**엣지 AI로 독거 노인의 삶을 지키는 플랫폼입니다.**

---

## 요약

| 질문 | 답변 |
|------|------|
| **무엇을?** | 엣지 AI 낙상 감지 + 균형 게임 + 즉각 알림 시스템 |
| **누구를 위해?** | 독거 노인, 요양병원·복지시설 거주자 |
| **언제?** | 24시간 — 보호자 없이 혼자 있을 때 항상 |
| **어디서?** | 거실, 침실, 계단, 복도 |
| **왜?** | 독거 노인의 낙상은 수 시간 동안 아무도 모른다 |
| **어떻게?** | 단일 카메라 + 경량 엣지 AI + 즉각 알림 (문자/푸시/카카오톡) |

---

*Team 4 · 초코하임 · ICCAS 2026*