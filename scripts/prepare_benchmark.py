"""Download a deterministic, small benchmark subset from a public HF dataset."""
import hashlib, json, random, urllib.request
from pathlib import Path

ROOT = Path(__file__).parents[1]
META = ROOT / "hf-meta.json"
OUT = ROOT / "data" / "benchmark"
DATASET = "Dhurgananth/waste-garbage-management-dataset"
SOURCE = "https://huggingface.co/datasets/" + DATASET + "/resolve/main/"
MAPPING = {"metal": "can", "glass": "glass", "paper": "paper", "cardboard": "paper", "plastic": "plastic", "trash": "general"}
random.seed(20261109)

meta = json.loads(META.read_text(encoding="utf-8"))
files = [x["rfilename"] for x in meta["siblings"] if x["rfilename"].lower().endswith((".jpg", ".jpeg", ".png", ".webp"))]
selected = []
for source_class, target_class in MAPPING.items():
    candidates = sorted(x for x in files if x.lower().startswith(source_class + "/"))
    random.shuffle(candidates)
    # 5 tuning + 7 evaluation images from each source class; paper receives
    # both source classes, giving 30 tune and 70 eval overall.
    selected.extend((x, target_class, "tune" if i < 5 else "eval") for i, x in enumerate(candidates[:12]))
if len(selected) != 72:
    raise SystemExit(f"Unexpected source selection: {len(selected)}")
# Add 28 more evaluation samples, preserving deterministic ordering.
used = {x[0] for x in selected}
for source_class, target_class in MAPPING.items():
    candidates = sorted(x for x in files if x.lower().startswith(source_class + "/") and x not in used)
    random.shuffle(candidates)
    for source_file in candidates[:max(0, 100 - len(selected))]:
        selected.append((source_file, target_class, "eval"))
        used.add(source_file)
        if len(selected) == 100: break
    if len(selected) == 100: break
if len(selected) != 100 or sum(x[2] == "tune" for x in selected) != 30:
    raise SystemExit(f"Expected 30 tune / 70 eval, got {sum(x[2] == 'tune' for x in selected)} / {sum(x[2] == 'eval' for x in selected)}")

manifest = []
for index, (source_file, target_class, split) in enumerate(selected):
    destination = OUT / split / target_class / f"{index:03d}_{Path(source_file).name}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(SOURCE + source_file, destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    manifest.append({"file": str(destination.relative_to(ROOT)).replace("\\", "/"), "source": SOURCE + source_file, "source_class": source_file.split("/", 1)[0], "target_class": target_class, "split": split, "sha256": digest, "license": "MIT", "dataset": DATASET})
(ROOT / "data" / "benchmark-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"total": len(manifest), "tune": sum(x["split"] == "tune" for x in manifest), "eval": sum(x["split"] == "eval" for x in manifest)}, ensure_ascii=False))
