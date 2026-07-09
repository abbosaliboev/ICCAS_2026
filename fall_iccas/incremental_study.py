"""
Incremental data-size study: does the physics (velocity/acceleration) filter help
MORE when training data is scarce?

Trains the two-stage detector on growing subject sets — {1}, {1,2}, {1,2,3}, ...,
{1..17} — and records, for each size:
  - ST-GCN alone (Stage 1)         : Accuracy, Fall F1
  - ST-GCN + Physics (Two-stage)   : Accuracy, Fall F1
  - physics gain ΔF1               : how much the physics rescue adds
  - rescue zone [rescue_thr, stage1_thr) and velocity / acceleration thresholds
  - test subjects + count

Hypothesis (to be verified by the data, not assumed): with few subjects the deep
model is weak and physics helps; as data grows the model catches up and the
tuned physics thresholds shrink toward 0. This is the basis for the "physics helps
in the low-data regime" contribution — relevant because real elderly fall data is
scarce (the elderly cannot stage falls to build a dataset).

Reuses the full 17-subject cv_dataset (subsets it per run — no re-extraction).

Usage:
  cd fall_iccas
  python incremental_study.py --data-dir experiments/subject1_to_17/cv_dataset
"""

import os, re, json, argparse, subprocess, sys


def parse_results(results_path):
    """Pull the two Accuracy / Fall F1 pairs + test count from a results.txt."""
    txt = open(results_path, encoding="utf-8", errors="ignore").read()
    accs = re.findall(r"Accuracy\s*:\s*([0-9.]+)", txt)
    f1s  = re.findall(r"Fall F1\s*:\s*([0-9.]+)", txt)
    m_test = re.search(r"test=(\d+)", txt)
    if len(accs) < 2 or len(f1s) < 2:
        return None
    return {
        "s1_acc": float(accs[0]), "s1_f1": float(f1s[0]),
        "s2_acc": float(accs[1]), "s2_f1": float(f1s[1]),
        "n_test": int(m_test.group(1)) if m_test else None,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True,
                    help="Full cv_dataset (e.g. experiments/subject1_to_17/cv_dataset)")
    ap.add_argument("--out-root", default="experiments/incremental",
                    help="Where per-size checkpoints/results go")
    ap.add_argument("--max-subjects", type=int, default=17)
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    rows = []

    for k in range(1, args.max_subjects + 1):
        subjects = list(range(1, k + 1))
        ckpt_dir = os.path.join(args.out_root, f"subj_1_to_{k}")
        results_path = os.path.join(ckpt_dir, "results.txt")

        # resume: skip if already trained
        if not os.path.exists(results_path):
            print(f"\n===== Training on {k} subject(s): {subjects} =====")
            cmd = [sys.executable, os.path.join(here, "train_two_stage.py"),
                   "--data-dir", args.data_dir,
                   "--ckpt-dir", ckpt_dir,
                   "--subjects", *map(str, subjects)]
            subprocess.run(cmd, check=True)
        else:
            print(f"[skip] {k} subjects — results exist")

        metrics = parse_results(results_path)
        cfg = json.load(open(os.path.join(ckpt_dir, "two_stage_config.json")))
        if metrics is None:
            print(f"[warn] could not parse metrics for k={k}")
            continue

        rows.append({
            "k": k, "subjects": subjects, **metrics,
            "stage1_thr": cfg["stage1_threshold"],
            "rescue_thr": cfg["rescue_threshold"],
            "vel_thr": cfg["vel_threshold"],
            "acc_thr": cfg["acc_threshold"],
        })

    # ── write the study table ──────────────────────────────────────────────────
    md = ["# Incremental data-size study — does physics help more with less data?",
          "",
          "Two-stage detector trained on growing subject sets (subject-stratified split).",
          "ΔF1 = Two-stage Fall F1 − Stage-1 Fall F1 = what the physics rescue adds.",
          "",
          "| #Subj | Subjects | N test | S1 Acc | S1 F1 | 2S Acc | 2S F1 | ΔF1 (physics) | Rescue zone | Vel thr | Acc thr |",
          "|:---:|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|"]
    for r in rows:
        subj = f"1–{r['k']}" if r["k"] > 1 else "1"
        rescue = f"{r['rescue_thr']:.2f}–{r['stage1_thr']:.2f}"
        d = r["s2_f1"] - r["s1_f1"]
        md.append(
            f"| {r['k']} | Subject {subj} | {r['n_test']} | "
            f"{r['s1_acc']:.4f} | {r['s1_f1']:.4f} | {r['s2_acc']:.4f} | {r['s2_f1']:.4f} | "
            f"{d:+.4f} | {rescue} | {r['vel_thr']:.5f} | {r['acc_thr']:.5f} |")
    md += ["",
           "**How to read it:** if ΔF1 (the physics gain) is larger at small #Subj and "
           "shrinks toward 0 as #Subj grows — and the Vel/Acc thresholds also shrink toward 0 — "
           "that is the evidence that physics matters most in the low-data regime."]

    out_md = os.path.join(here, "INCREMENTAL_STUDY.md")
    open(out_md, "w", encoding="utf-8").write("\n".join(md) + "\n")
    out_json = os.path.join(args.out_root, "incremental_summary.json")
    os.makedirs(args.out_root, exist_ok=True)
    json.dump(rows, open(out_json, "w"), indent=2)

    print("\n".join(md))
    print(f"\nSaved: {out_md}  and  {out_json}")


if __name__ == "__main__":
    main()
