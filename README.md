# Bewosai — Business Management App

Small business management app (Nepal) with billing, inventory, parties, purchases, expenses, banking, and reports.

## Stack
- **Backend**: Django + Django REST Framework, JWT auth (`rest_framework_simplejwt`), SQLite (dev) / Postgres (prod)
- **Web frontend**: React + Vite, deployed at `bewosaiapp.vercel.app`
- **Mobile/desktop frontend**: Flutter (`bewosai_app/`)

Both frontends talk to the same Django API.

## Folder structure
```
bepar-mern/
  backend/      Django REST API
  client/       React + Vite web app
  bewosai_app/   Flutter app (mobile/desktop/web)
```

## 1. Backend setup
```bash
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
copy .env.example .env       # fill in SECRET_KEY, email settings, etc.
python manage.py migrate
python manage.py runserver
```
Backend runs at `http://127.0.0.1:8000`.

## 2. Web client setup
```bash
cd client
npm install
npm run dev
```
Runs at `http://localhost:5173`.

## 3. Flutter app setup
```bash
cd bewosai_app
flutter pub get
flutter run -d chrome   # or a connected device/emulator
```
Note: the API base URL is a compile-time constant (`kIsWeb` check) — a full rebuild is required after changing it, not just hot reload.

## Deployment
- **Backend**: Render (see `render.yaml`)
- **Web client**: Vercel (see `client/vercel.json`)

## Auth flow
Email OTP login → JWT → business selection → main app.
