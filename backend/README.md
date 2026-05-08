# FastAPI Backend

## Install

```bash
.\.venv311\Scripts\python.exe -m pip install -r requirements.txt
```

## Environment Variables

Create a `.env` file in the `backend` directory if you want to override defaults.

```env
APP_NAME=Start On API
APP_VERSION=0.1.0
APP_ENV=development
LOG_LEVEL=INFO
API_HOST=0.0.0.0
API_PORT=8000
API_RELOAD=false
API_V1_PREFIX=/api/v1
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
SUPABASE_ANON_KEY=your-supabase-anon-key
GEMINI_API_KEY=your-gemini-api-key
```

The backend reads `backend/.env` even if the server is started from the project root.

Required at startup:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

Optional unless you use the related feature:
- `SUPABASE_ANON_KEY`
- `GEMINI_API_KEY`
- `NOTION_TOKEN_ENCRYPTION_KEY`

Notion tokens are handled per request and are not stored on the server.

## Run

Run the command inside the `backend` directory.

```bash
.\.venv311\Scripts\python.exe -m app.main
```

If you prefer `uvicorn` directly, use:

```bash
.\.venv311\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Or use the included launcher:

```bash
.\run_backend.ps1
```

Windows note:

- In some Windows environments, `--reload` can fail during Uvicorn's reloader startup with `PermissionError: [WinError 5]`.
- If that happens, keep `API_RELOAD=false` and run without `--reload`.
- Do not run bare `python` or bare `uvicorn` if your shell resolves to `C:\msys64\ucrt64\bin\python.exe` or `C:\msys64\ucrt64\bin\uvicorn.exe`.
- If you see `C:\msys64\...` in the traceback, you are not using the project virtual environment.

Open:

- `http://127.0.0.1:8000/docs`
- `http://127.0.0.1:8000/redoc`

Android emulator note:

- The Flutter app uses `http://10.0.2.2:8000` by default.
- That only works when the backend is running on your PC and listening on `0.0.0.0:8000`.
- If the server is bound to `127.0.0.1` only, the emulator will show `SocketException: Connection refused`.

## API Examples

### Health Check

Request:

```bash
curl http://127.0.0.1:8000/api/v1/health
```

Response:

```json
{
  "success": true,
  "data": {
    "status": "ok",
    "app_name": "Start On API",
    "environment": "development",
    "version": "0.1.0"
  },
  "error": null
}
```

### Quest Generation

Request:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/quests/generate \
  -H "Content-Type: application/json" \
  -d "{\"prompt\":\"Prepare project presentation\",\"difficulty\":\"hard\",\"category\":\"work\",\"max_items\":3}"
```

Response:

```json
{
  "success": true,
  "data": {
    "quests": [
      {
        "title": "Prepare project presentation",
        "difficulty": "hard",
        "category": "work",
        "exp": 100,
        "defaultDurationSeconds": 5400,
        "reason": "Applied explicit difficulty. Applied explicit category."
      }
    ]
  },
  "error": null
}
```

### OCR Text Quest Extraction

Request:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/quests/from-text \
  -H "Content-Type: application/json" \
  -d "{\"raw_text\":\"- Buy groceries\n- Buy groceries\n- Clean kitchen\n1234\nStudy chapter 3\"}"
```

Response:

```json
{
  "success": true,
  "data": {
    "quests": [
      {
        "title": "Buy groceries",
        "difficulty": "easy",
        "category": "home",
        "exp": 30,
        "defaultDurationSeconds": 1500,
        "reason": "Generated from cleaned OCR text."
      },
      {
        "title": "Clean kitchen",
        "difficulty": "easy",
        "category": "home",
        "exp": 30,
        "defaultDurationSeconds": 1500,
        "reason": "Generated from cleaned OCR text."
      },
      {
        "title": "Study chapter 3",
        "difficulty": "normal",
        "category": "study",
        "exp": 50,
        "defaultDurationSeconds": 2700,
        "reason": "Generated from cleaned OCR text."
      }
    ],
    "cleaned_lines": [
      "Buy groceries",
      "Clean kitchen",
      "Study chapter 3"
    ],
    "duplicate_removed_count": 1
  },
  "error": null
}
```

### Notion Sync

Request:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/integrations/notion/sync \
  -H "Content-Type: application/json" \
  -d "{\"notion_api_token\":\"secret_xxx\",\"database_url\":\"https://www.notion.so/your-workspace/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\"}"
```

Response:

```json
{
  "success": true,
  "data": {
    "database_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "database_title": "My Notion Tasks",
    "quests": [
      {
        "title": "Prepare weekly report",
        "difficulty": "normal",
        "category": "work",
        "exp": 50,
        "defaultDurationSeconds": 2700,
        "reason": "Generated from Notion sync."
      }
    ]
  },
  "error": null
}
```

## Structure

- `app/main.py`: FastAPI entry point
- `app/api/routes`: Route handlers
- `app/schemas`: Request and response models
- `app/services`: Business logic layer
- `app/repositories`: persistence abstractions and future Supabase-backed implementations
- `app/providers`: External integration and generation providers
- `app/core`: App settings and bootstrap-related modules

Several endpoints are still placeholder-backed with mock repositories so the API surface is ready before the Supabase implementations are completed.
