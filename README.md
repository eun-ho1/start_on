# Start On

`Start On` is a Flutter-based productivity app with a FastAPI backend. It helps users turn goals into manageable quests, run focused timers, and connect external sources such as OCR text, Notion, and backend-driven quest generation.

## Project Structure

- `lib/`: Flutter application source
- `backend/`: FastAPI backend
- `test/`: Flutter tests

## Main Features

- Quest creation and management
- Focus timer workflow
- OCR-based quest extraction
- Notion sync support
- Backend API integration
- Supabase-ready data flow

## Run The Flutter App

```bash
flutter pub get
flutter run
```

## Run The Backend

Backend setup and API examples are documented in [backend/README.md](backend/README.md).

Quick start:

```bash
cd backend
.\.venv311\Scripts\python.exe -m pip install -r requirements.txt
.\run_backend.ps1
```

## Environment

- Flutter SDK
- Dart SDK `^3.11.4`
- Python virtual environment for `backend/`

## Notes

- The Android emulator uses `http://10.0.2.2:8000` to reach the local backend.
- Backend environment variables can be based on `backend/.env.example`.
