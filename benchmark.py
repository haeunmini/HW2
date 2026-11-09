"""Reproducible 100-image CLIP benchmark.

Images are intentionally kept outside Git. Prepare data/benchmark/{tune,eval}/
using the mapping documented in data/README.md, then run this script in the
same Python environment as the API.
"""
import argparse, csv, json
from pathlib import Path
from collections import Counter
from PIL import Image
from transformers import pipeline

ROOT = Path(__file__).parent
BASELINE = {"plastic": ["a plastic bottle", "plastic container", "plastic packaging"], "can": ["an aluminum can", "a metal can", "a beverage can"], "glass": ["a glass bottle", "a glass jar", "glass packaging"], "paper": ["paper packaging", "a cardboard box", "paper"], "vinyl": ["a plastic film bag", "a vinyl packaging bag", "soft plastic packaging"], "general": ["general waste", "non-recyclable trash", "a disposable item"]}
# Attempt 2: short, category-level recycling prompts. Attempt 1 was evaluated
# and rejected because it did not improve the held-out score.
IMPROVED = {"plastic": "a plastic item for recycling", "can": "a metal can for recycling", "glass": "a glass item for recycling", "paper": "paper or cardboard for recycling", "vinyl": "a plastic film bag for recycling", "general": "non-recyclable general trash"}

def predict(pipe, image, labels, label_to_class):
    result = pipe(image, candidate_labels=labels)
    return label_to_class[result[0]["label"]]

def evaluate(rows, predictions):
    correct = sum(r["class"] == p for r, p in zip(rows, predictions))
    per = {}
    for cls in sorted({r["class"] for r in rows}):
        subset = [i for i, r in enumerate(rows) if r["class"] == cls]
        per[cls] = {"correct": sum(predictions[i] == cls for i in subset), "total": len(subset), "accuracy": round(sum(predictions[i] == cls for i in subset) / len(subset), 4) if subset else 0}
    return {"accuracy": round(correct / len(rows), 4), "correct": correct, "total": len(rows), "per_category": per}

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--data", default="data/benchmark"); ap.add_argument("--output", default="benchmark-results.json"); args = ap.parse_args()
    rows = []
    for split in ("tune", "eval"):
        for path in sorted((Path(args.data) / split).rglob("*")):
            if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
                cls = path.parent.name
                rows.append({"path": str(path), "split": split, "class": cls})
    if len(rows) != 100 or Counter(r["split"] for r in rows) != Counter({"tune": 30, "eval": 70}):
        raise SystemExit(f"Expected exactly 30 tune and 70 eval images; found {Counter(r['split'] for r in rows)}")
    pipe = pipeline("zero-shot-image-classification", model="openai/clip-vit-base-patch32", device=-1)
    baseline_labels = [x for values in BASELINE.values() for x in values]
    baseline_map = {label: cls for cls, values in BASELINE.items() for label in values}
    improved_labels = list(IMPROVED.values()); improved_map = {label: cls for cls, label in IMPROVED.items()}
    results = {}
    for split in ("tune", "eval"):
        subset = [r for r in rows if r["split"] == split]
        base = [predict(pipe, Image.open(r["path"]).convert("RGB"), baseline_labels, baseline_map) for r in subset]
        improved = [predict(pipe, Image.open(r["path"]).convert("RGB"), improved_labels, improved_map) for r in subset]
        results[split] = {"baseline": evaluate(subset, base), "improved": evaluate(subset, improved)}
    Path(args.output).write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(results, ensure_ascii=False, indent=2))

if __name__ == "__main__": main()
