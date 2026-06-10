# AgroScan Tomato Disease Detector

AgroScan is a Flutter app backed by a Django REST API. Users sign in with Google, upload tomato leaf images, receive disease predictions, and their scan history is stored in the backend database.

## What Stores Scan Data

The Django backend saves each completed scan in `backend.api.models.ScanHistory` with:

- authenticated user
- uploaded image path
- predicted disease class
- confidence score
- creation date

The backend now supports Neon Postgres through the `DATABASE_URL` environment variable. If `DATABASE_URL` is not set, it falls back to the local `db.sqlite3` file.

## 1. Create A Neon Database

1. Open [Neon](https://neon.tech/) and create a project.
2. Create or choose a database for AgroScan.
3. Copy the pooled connection string from Neon.
4. Make sure the connection string includes `sslmode=require`.

It should look similar to:

```text
postgresql://user:password@ep-example-pooler.region.aws.neon.tech/dbname?sslmode=require
```

## 2. Configure Backend Environment

From the repository root, copy the example env file:

```powershell
Copy-Item .env.example .env
```

Edit `.env` and set:

```text
DJANGO_SECRET_KEY=replace-with-a-long-random-secret
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,your-backend-domain.com
CORS_ALLOW_ALL_ORIGINS=False
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,https://your-frontend-domain.com
GOOGLE_OAUTH_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
DATABASE_URL=your-neon-pooled-connection-string
```

For local mobile testing, add your local backend origin to `CORS_ALLOWED_ORIGINS` if needed.

## 3. Install Backend Dependencies

From the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

The root `requirements.txt` installs `backend/requirements.txt`, including `dj-database-url` and `psycopg2-binary` for Neon.

## 4. Create Neon Tables

Run Django migrations after `DATABASE_URL` is set:

```powershell
python manage.py migrate
```

This creates the auth tables and the scan history table in Neon.

## 5. Run The Backend

```powershell
python manage.py runserver 0.0.0.0:8000
```

The API base URL will be:

```text
http://127.0.0.1:8000/api
```

## 6. Run The Flutter App

From this Flutter app folder:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

For an Android emulator, use:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

For a hosted backend, replace the URL with your deployed API URL:

```powershell
flutter run --dart-define=API_BASE_URL=https://your-backend-domain.com/api
```

## 7. Verify Scan Storage

1. Sign in with Google.
2. Upload a tomato leaf image.
3. Confirm the scan result appears in the app.
4. Open the History tab and confirm the scan is listed.
5. In Neon, open the SQL editor and run:

```sql
select id, user_id, disease, confidence, created_at
from api_scanhistory
order by created_at desc;
```

If rows appear there, scan persistence is working.

## Useful Files

- Backend settings: `../backend/settings.py`
- Scan model: `../backend/api/models.py`
- Scan upload API: `../backend/api/views.py`
- Flutter API client: `lib/services/api_service.dart`
- Google button UI: `lib/screens/auth_screen.dart`
