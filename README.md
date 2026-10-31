# 분리배출 분류기

이미지를 업로드하면 CLIP 제로샷 이미지 분류로 쓰레기 재질을 추정하고, 분리배출 요령을 안내하는 FastAPI 웹 애플리케이션입니다. 결과는 참고용 추정치이며 지역별 배출 기준을 확인해야 합니다.

## 설치

Python 3.10 이상을 준비한 뒤 프로젝트 루트에서 실행합니다.

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
py -m pip install -r requirements.txt
```

## 모델 준비

첫 분석 시 Hugging Face의 `openai/clip-vit-base-patch32` 모델을 자동으로 내려받습니다. 인터넷 연결과 충분한 디스크 공간이 필요하며, 모델 캐시는 프로젝트에 포함하지 않습니다.

다른 모델을 사용하려면 환경변수 `WASTE_MODEL`에 Hugging Face 모델 ID를 지정하세요.

```powershell
$env:WASTE_MODEL = "openai/clip-vit-base-patch32"
```

## 실행

```powershell
py -m uvicorn app:app --host 127.0.0.1 --port 8000
```

또는 Windows PowerShell에서 `.\run.ps1`을 실행할 수 있습니다. 브라우저에서 <http://127.0.0.1:8000>을 열고 JPG, PNG, WEBP 등 이미지를 업로드하세요. 업로드 이미지는 10MB 이하만 허용됩니다.

모델을 사용할 수 없는 경우에도 서버는 실행되며, `/api/health`에서 모델 상태를 확인할 수 있습니다. 이 경우 결과는 모델 미사용 대체 결과로 표시됩니다.
