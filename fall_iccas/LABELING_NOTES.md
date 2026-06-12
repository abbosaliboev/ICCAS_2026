# UP-Fall Dataset — Automatic Labeling / 자동 라벨링 / Avtomatik Labeling

> **Language / 언어 / Til**
> - [🇺🇸 English](#english)
> - [🇰🇷 한국어](#korean)
> - [🇺🇿 O'zbekcha](#uzbek)

---

<a name="english"></a>
# 🇺🇸 English

## What was done?

The `label_dataset.py` script was written. It reads all CSV files in the UP-Fall dataset, automatically adds a `label` column to each row (`1` = fall, `0` = normal activity), and merges everything into a single `labeled_dataset.csv` file.

## Dataset structure

```
dataset/
  SubjectN/
    ActivityN/
      TrialN/
        SubjectNActivityNTrialN.csv
```

Each CSV file has 2 header rows (the first — sensor group names, the second — axis names), followed by the sensor data. Each row has 47 columns (the documentation says 46, but there is actually one extra column).

## Labeling logic

The UP-Fall dataset has 11 activities. Based on the paper, they can be split into two groups:

| Activity | Name | Label |
|---|---|---|
| 1 | Falling forward (hands) | **1** — FALL |
| 2 | Falling forward (knees) | **1** — FALL |
| 3 | Falling sideways | **1** — FALL |
| 4 | Falling backward | **1** — FALL |
| 5 | Hitting obstacle while walking | **1** — FALL |
| 6 | Sitting abruptly | **0** — NO-FALL |
| 7 | Walking | **0** — NO-FALL |
| 8 | Standing | **0** — NO-FALL |
| 9 | Sitting | **0** — NO-FALL |
| 10 | Picking up an object | **0** — NO-FALL |
| 11 | Jumping | **0** — NO-FALL |

**Why this way?**
The label is determined from the folder name (ActivityN), not from columns inside the CSV. This is reliable because the folder name was assigned by the dataset authors — no need to parse columns inside the CSV.

## CSV reading problem and solution

**Problem:** Pandas raised an error with `header=[0,1]` because the column counts in the two header rows don't match (the first row has merged cells).

**Solution:** `skiprows=2` was used — both header rows are skipped and column names are set manually (via the `COLUMN_NAMES` list).

## Output file — `labeled_dataset.csv`

Result for Subject1:

| | Count |
|---|---|
| Total rows | 17,932 |
| FALL rows | 2,832 |
| NO-FALL rows | 15,100 |

Main columns in the file:
- `ankle_acc_x/y/z`, `ankle_gyr_x/y/z`, `ankle_lux`
- `pocket_*`, `belt_*`, `neck_*`, `wrist_*` (same format)
- `brain`, `ir1`–`ir6`
- `subject_id`, `activity_id`, `trial_id`, `activity_name`
- **`label`** — target column (0 or 1)

## For the remaining subjects

After downloading the other subjects, just place them into `dataset/SubjectN/` and re-run the script. The script automatically finds all subjects and merges them into one big CSV.

```bash
python label_dataset.py
```

*Source: Lourdes Martínez-Villaseñor et al., "UP-Fall Detection Dataset: A Multimodal Approach", Sensors 19(9), 1988, 2019.*

## CV Dataset (for camera images)

Dataset for the CV model, based on camera images rather than sensor CSVs:

```
cv_dataset/
  X.npy    # (N, 30, 17, 3) — N windows, 30 frames, 17 joints, [x, y, conf]
  y.npy    # (N,) — 0/1 labels
  meta.csv # subject, activity, trial, start_frame
```

`prepare_cv_dataset.py` is used. Labeling logic is the same — from the activity folder name.

### Problems solved

**Camera folder naming error:**
In the dataset, every camera folder inside `Subject1/ActivityN/TrialN/` was named `Subject1Activity2TrialXCameraX` (all of them Activity2). Fixed 54 folders with a PowerShell script, using the activity number from the parent folder.

**YOLO zero-frame problem:**
During falls, YOLO failed to find the person and output `[0, 0, 0]` keypoints. In fall sequences this was 14.5% (Activity 2 — falling backward — was especially bad, with some windows 100% zero).

Solution:
1. `conf=0.1` — detect more poses with a low threshold
2. `interpolate_zero_frames()` — fill zero frames with the last detected one

Result: **0% zero frames** (from 14.5%)

---

<a name="korean"></a>
# 🇰🇷 한국어

## 무엇을 했는가?

`label_dataset.py` 스크립트를 작성했습니다. 이 스크립트는 UP-Fall 데이터셋의 모든 CSV 파일을 읽어 각 행에 자동으로 `label` 열을 추가하고(`1` = 낙상, `0` = 정상 동작), 전체를 하나의 `labeled_dataset.csv` 파일로 병합합니다.

## 데이터셋 구조

```
dataset/
  SubjectN/
    ActivityN/
      TrialN/
        SubjectNActivityNTrialN.csv
```

각 CSV 파일에는 2개의 헤더 행이 있고(첫 번째 — 센서 그룹 이름, 두 번째 — 축 이름), 그 다음에 센서 데이터가 옵니다. 각 행에는 47개의 열이 있습니다 (문서에는 46개라고 되어 있지만 실제로는 추가 열이 하나 더 있음).

## 라벨링 로직

UP-Fall 데이터셋에는 11개의 activity가 있습니다. 논문에 따라 두 그룹으로 나눌 수 있습니다:

| Activity | 이름 | 라벨 |
|---|---|---|
| 1 | 앞으로 넘어짐 (손) | **1** — FALL |
| 2 | 앞으로 넘어짐 (무릎) | **1** — FALL |
| 3 | 옆으로 넘어짐 | **1** — FALL |
| 4 | 뒤로 넘어짐 | **1** — FALL |
| 5 | 걷다가 장애물에 부딪힘 | **1** — FALL |
| 6 | 갑자기 앉기 | **0** — NO-FALL |
| 7 | 걷기 | **0** — NO-FALL |
| 8 | 서 있기 | **0** — NO-FALL |
| 9 | 앉아 있기 | **0** — NO-FALL |
| 10 | 물건 줍기 | **0** — NO-FALL |
| 11 | 점프 | **0** — NO-FALL |

**왜 이렇게 하는가?**
라벨은 폴더 이름(ActivityN)에서 결정되며, CSV 내부의 열에서 결정되지 않습니다. 폴더 이름은 데이터셋 제작자가 지정한 것이므로 신뢰할 수 있고 — CSV 내부 열을 파싱할 필요가 없습니다.

## CSV 읽기 문제와 해결

**문제:** 두 헤더 행의 열 개수가 일치하지 않아(첫 번째 행에 병합 셀이 있음) Pandas의 `header=[0,1]`이 오류를 발생시켰습니다.

**해결:** `skiprows=2`를 사용 — 두 헤더 행을 건너뛰고 열 이름을 수동으로 지정했습니다 (`COLUMN_NAMES` 리스트 사용).

## 출력 파일 — `labeled_dataset.csv`

Subject1의 결과:

| | 개수 |
|---|---|
| 전체 행 | 17,932 |
| FALL 행 | 2,832 |
| NO-FALL 행 | 15,100 |

파일의 주요 열:
- `ankle_acc_x/y/z`, `ankle_gyr_x/y/z`, `ankle_lux`
- `pocket_*`, `belt_*`, `neck_*`, `wrist_*` (동일 형식)
- `brain`, `ir1`–`ir6`
- `subject_id`, `activity_id`, `trial_id`, `activity_name`
- **`label`** — 타겟 열 (0 또는 1)

## 나머지 subject에 대해

다른 subject를 다운로드한 후 `dataset/SubjectN/` 폴더에 넣고 스크립트를 다시 실행하면 됩니다. 스크립트가 자동으로 모든 subject를 찾아 하나의 큰 CSV로 병합합니다.

```bash
python label_dataset.py
```

*출처: Lourdes Martínez-Villaseñor et al., "UP-Fall Detection Dataset: A Multimodal Approach", Sensors 19(9), 1988, 2019.*

## CV Dataset (카메라 이미지용)

센서 CSV가 아닌 카메라 이미지 기반의 CV 모델용 데이터셋:

```
cv_dataset/
  X.npy    # (N, 30, 17, 3) — N개 윈도우, 30 프레임, 17 관절, [x, y, conf]
  y.npy    # (N,) — 0/1 라벨
  meta.csv # subject, activity, trial, start_frame
```

`prepare_cv_dataset.py`를 사용합니다. 라벨링 로직은 동일 — activity 폴더 이름 기준.

### 해결한 문제들

**카메라 폴더 이름 오류:**
데이터셋에서 `Subject1/ActivityN/TrialN/` 안의 모든 카메라 폴더가 `Subject1Activity2TrialXCameraX`로 이름 지어져 있었습니다 (전부 Activity2). 상위 폴더의 activity 번호를 이용한 PowerShell 스크립트로 54개 폴더를 수정했습니다.

**YOLO zero frame 문제:**
낙상 중에 YOLO가 사람을 찾지 못해 `[0, 0, 0]` 키포인트를 출력했습니다. 낙상 시퀀스에서 이 비율이 14.5%였습니다 (Activity 2 — 뒤로 넘어짐 — 이 특히 심각해서 일부 윈도우는 100% zero).

해결:
1. `conf=0.1` — 낮은 임계값으로 더 많은 자세 감지
2. `interpolate_zero_frames()` — zero frame을 마지막으로 감지된 프레임으로 채움

결과: **zero frame 0%** (14.5%에서)

---

<a name="uzbek"></a>
# 🇺🇿 O'zbekcha

## Nima qilindi?

`label_dataset.py` skripti yozildi. Bu skript UP-Fall datasetidagi barcha CSV fayllarni o'qib, har bir qatorga avtomatik `label` ustuni qo'shadi (`1` = yiqilish, `0` = normal harakat) va hammasini bitta `labeled_dataset.csv` faylga birlashtiradi.

## Dataset strukturasi

```
dataset/
  SubjectN/
    ActivityN/
      TrialN/
        SubjectNActivityNTrialN.csv
```

Har bir CSV faylida 2 ta header qator bor (birinchisi — sensor guruhi nomlari, ikkinchisi — o'q nomlari), keyin sensor ma'lumotlari keladi. Har bir qatorda 47 ustun bor (dokumentatsiyada 46 ta deyilgan, lekin aslida bitta qo'shimcha ustun ham mavjud).

## Labeling mantigi

UP-Fall datasetida 11 ta activity bor. Maqola asosida ularni ikki guruhga bo'lish mumkin:

| Activity | Nomi | Label |
|---|---|---|
| 1 | Falling forward (hands) | **1** — FALL |
| 2 | Falling forward (knees) | **1** — FALL |
| 3 | Falling sideways | **1** — FALL |
| 4 | Falling backward | **1** — FALL |
| 5 | Hitting obstacle while walking | **1** — FALL |
| 6 | Sitting abruptly | **0** — NO-FALL |
| 7 | Walking | **0** — NO-FALL |
| 8 | Standing | **0** — NO-FALL |
| 9 | Sitting | **0** — NO-FALL |
| 10 | Picking up an object | **0** — NO-FALL |
| 11 | Jumping | **0** — NO-FALL |

**Nega shunday?**
Label papka nomidan (ActivityN) aniqlanadi, CSV ichidagi ustunlardan emas. Bu ishonchli, chunki papka nomi dataset egasi tomonidan belgilangan — CSV ichidagi ustunlarni o'qish shart emas.

## CSV o'qishdagi muammo va yechim

**Muammo:** Pandas `header=[0,1]` bilan o'qishda xato berdi, chunki ikkala header qatordagi ustunlar soni mos kelmaydi (birinchi qatorda merged cell-lar bor).

**Yechim:** `skiprows=2` ishlatildi — ikkala header qator o'tkazib yuborildi va ustun nomlari qo'lda belgilandi (`COLUMN_NAMES` ro'yxati orqali).

## Chiqish fayli — `labeled_dataset.csv`

Subject1 uchun natija:

| | Soni |
|---|---|
| Jami qatorlar | 17,932 |
| FALL qatorlar | 2,832 |
| NO-FALL qatorlar | 15,100 |

Fayldagi asosiy ustunlar:
- `ankle_acc_x/y/z`, `ankle_gyr_x/y/z`, `ankle_lux`
- `pocket_*`, `belt_*`, `neck_*`, `wrist_*` (bir xil format)
- `brain`, `ir1`–`ir6`
- `subject_id`, `activity_id`, `trial_id`, `activity_name`
- **`label`** — maqsad ustun (0 yoki 1)

## Keyingi subjectlar uchun

Boshqa subjectlar yuklangandan keyin ularni `dataset/SubjectN/` papkasiga solib, skriptni qayta ishga tushirish kifoya. Skript avtomatik barcha subjectlarni topib, bitta katta CSV ga birlashtiradi.

```bash
python label_dataset.py
```

*Manba: Lourdes Martínez-Villaseñor et al., "UP-Fall Detection Dataset: A Multimodal Approach", Sensors 19(9), 1988, 2019.*

## CV Dataset (kamera rasmlari uchun)

Sensor CSV lari emas, kamera rasmlari asosida CV model uchun dataset:

```
cv_dataset/
  X.npy    # (N, 30, 17, 3) — N ta window, 30 frame, 17 joint, [x, y, conf]
  y.npy    # (N,) — 0/1 labels
  meta.csv # subject, activity, trial, start_frame
```

`prepare_cv_dataset.py` ishlatiladi. Labeling mantigi bir xil — activity papka nomidan.

### Hal qilingan muammolar

**Camera papka nomi xatosi:**
Dataset da barcha `Subject1/ActivityN/TrialN/` ichidagi kamera papkasi `Subject1Activity2TrialXCameraX` deb nomlangan edi (hammasi Activity2). PowerShell script bilan parent papkadagi activity raqamidan foydalanib 54 ta papka to'g'rilandi.

**YOLO zero frame muammosi:**
Yiqilish paytida YOLO odamni topa olmay `[0, 0, 0]` keypoint qo'yardi. Fall sequencelarda bu 14.5% edi (Activity 2 — orqaga yiqilish — ayniqsa yomon, ba'zi windowlarda 100% zero).

Yechim:
1. `conf=0.1` — past threshold bilan ko'proq holat aniqlansin
2. `interpolate_zero_frames()` — zero frame larga avvalgi aniqlanganidan foydalanish

Natija: **0% zero frame** (14.5% dan)
