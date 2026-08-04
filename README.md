<<<<<<< HEAD
# MERN OTP Auth (Real SMS OTP to Mobile Number)

This project uses:
- React + Vite frontend
- Node + Express backend
- MongoDB + Mongoose
- Twilio Verify for real SMS OTP delivery
- JWT after successful OTP verification

## What this project does
- Signup with **name + mobile number**
- Login with **mobile number only**
- Send a **real OTP by SMS** to the user's phone
- Verify OTP on the backend
- Create or log in the user only after Twilio approves the OTP
- Resend OTP with a small cooldown timer

## Important
- Use phone numbers in **E.164 format**, for example: `+97798XXXXXXXX`
- You need a **Twilio account** and a **Verify Service SID**
- If you are using a **Twilio trial account**, Twilio only sends OTP to phone numbers that you have verified inside Twilio first

## Folder structure
```bash
mern-otp-auth/
  client/
  server/
  README.md
```

## 1. Backend setup
```bash
cd server
npm install
cp .env.example .env
```

Edit `.env` and add your real values:
```env
PORT=5000
MONGO_URI=mongodb://127.0.0.1:27017/mern_otp_auth
JWT_SECRET=replace_with_a_long_random_secret

TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_VERIFY_SERVICE_SID=VAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Run backend:
```bash
npm run dev
```

## 2. Frontend setup
Open another terminal:
```bash
cd client
npm install
npm run dev
```

## 3. App URLs
- Frontend: `http://localhost:5173`
- Backend: `http://localhost:5000`

## 4. Twilio setup
1. Create a Twilio account
2. Open Twilio Verify in the console
3. Create a Verify Service
4. Copy these values into `.env`
   - `TWILIO_ACCOUNT_SID`
   - `TWILIO_AUTH_TOKEN`
   - `TWILIO_VERIFY_SERVICE_SID`
5. If you are still on Twilio trial, verify your own mobile number in Twilio before testing OTP

## 5. API routes
- `POST /api/auth/send-otp`
- `POST /api/auth/resend-otp`
- `POST /api/auth/verify-otp`
- `GET /api/me`

## Example request for sending OTP
```json
{
  "name": "Rajan",
  "phone": "+97798XXXXXXXX",
  "mode": "signup"
}
```

## Example request for verifying OTP
```json
{
  "name": "Rajan",
  "phone": "+97798XXXXXXXX",
  "code": "123456",
  "mode": "signup"
}
```

## Common issues
### OTP not received
- Check Twilio credentials
- Check Verify Service SID
- Make sure the phone number includes `+` and country code
- If using Twilio trial, make sure the recipient phone number is verified in Twilio
- Check whether your destination country and carrier support incoming Twilio Verify SMS

### Invalid OTP every time
- Make sure you enter the latest code
- Do not wait too long before entering it
- Request a new OTP if needed

## Notes
- This project sends **real SMS OTP**, not fake frontend-generated OTP
- For production, add rate limiting, logging, country restrictions, and stronger abuse protection
=======
# bewosyapp
>>>>>>> 776348f1fe8b5a2c776645cb70a42dc8858736a4
