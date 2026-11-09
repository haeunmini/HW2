import json, io, os
from pathlib import Path
from typing import Optional
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from PIL import Image

ROOT = Path(__file__).parent
with open(ROOT / "categories.json", encoding="utf-8") as f:
    CONFIG = json.load(f)
MODEL_ID = os.getenv("WASTE_MODEL", "openai/clip-vit-base-patch32")
DEPLOY_VERSION = os.getenv("APP_VERSION", "dev")
classifier = None
model_error: Optional[str] = None

def get_classifier():
    global classifier, model_error
    if classifier is not None or model_error:
        return classifier
    try:
        from transformers import pipeline
        classifier = pipeline("zero-shot-image-classification", model=MODEL_ID, device=-1)
    except Exception as exc:
        model_error = f"모델을 불러오지 못했습니다: {type(exc).__name__}"
    return classifier

def classify(image: Image.Image):
    pipe = get_classifier()
    if pipe:
        labels = [x for c in CONFIG["categories"] for x in c["labels"]]
        results = pipe(image, candidate_labels=labels)
        best = results[0]
        category = next(c for c in CONFIG["categories"] if best["label"] in c["labels"])
        return category, round(float(best["score"]), 4), "CLIP 제로샷 이미지 분류(추정)"
    # Keep the API usable when optional ML dependencies/model weights are unavailable.
    category = CONFIG["categories"][-1]
    return category, 0.0, "모델 미사용 대체 결과"

app = FastAPI(title="쓰레기 분리배출 분류기")
app.mount("/static", StaticFiles(directory=ROOT / "static"), name="static")

# Load the model when the application starts so /api/health reports the real
# readiness state and the first user request does not pay the model load cost.
get_classifier()

@app.get("/", response_class=HTMLResponse)
def index():
    return (ROOT / "static" / "index.html").read_text(encoding="utf-8")

@app.get("/api/health")
def health():
    return {"ok": True, "version": DEPLOY_VERSION, "model": MODEL_ID, "model_loaded": classifier is not None, "model_error": model_error}

@app.post("/api/analyze")
async def analyze(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "이미지 파일만 업로드할 수 있습니다.")
    data = await file.read()
    if len(data) > 10 * 1024 * 1024:
        raise HTTPException(413, "이미지는 10MB 이하만 업로드할 수 있습니다.")
    try:
        image = Image.open(io.BytesIO(data)).convert("RGB")
    except Exception:
        raise HTTPException(400, "손상되었거나 지원하지 않는 이미지입니다.")
    category, probability, method = classify(image)
    return {"category": category["name"], "category_id": category["id"], "probability": probability, "method": method, "tips": category["tips"], "version": DEPLOY_VERSION, "model": MODEL_ID, "notice":"AI 분석 결과는 추정치입니다. 지역·지자체별 분리배출 기준이 다를 수 있으니 반드시 지역 안내를 확인하세요."}

