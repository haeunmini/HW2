$ErrorActionPreference = 'Stop'
py -m pip install -r requirements.txt
py -m uvicorn app:app --host 127.0.0.1 --port 8000
