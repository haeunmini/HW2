FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/opt/huggingface \
    TRANSFORMERS_CACHE=/opt/huggingface \
    WASTE_MODEL=/opt/models/clip

WORKDIR /app

COPY requirements.txt ./
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

# Download the model into the image and verify that the same pipeline used by
# the API can load it. This makes container startup independent of the network.
RUN mkdir -p /opt/models/clip \
    && python -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='openai/clip-vit-base-patch32', local_dir='/opt/models/clip')" \
    && python -c "from transformers import pipeline; pipeline('zero-shot-image-classification', model='/opt/models/clip', device=-1); print('CLIP model load verified')"

COPY app.py categories.json ./
COPY static ./static

EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
