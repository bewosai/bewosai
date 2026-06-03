import dotenv from "dotenv";
dotenv.config();

export const env = {
  port: process.env.PORT || 5000,
  mongoUri: process.env.MONGO_URI,
  nodeEnv: process.env.NODE_ENV || "development",
  clientUrl: process.env.CLIENT_URL || "http://localhost:5173",
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET,
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET,
  accessTokenExpires: process.env.ACCESS_TOKEN_EXPIRES || "15m",
  refreshTokenExpires: process.env.REFRESH_TOKEN_EXPIRES || "365d",
  otpExpiresSeconds: Number(process.env.OTP_EXPIRES_SECONDS || 300),
  otpResendSeconds: Number(process.env.OTP_RESEND_SECONDS || 60),
  otpLength: Number(process.env.OTP_LENGTH || 6),
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID,
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN,
  twilioVerifyServiceSid: process.env.TWILIO_VERIFY_SERVICE_SID,
  smsProvider: process.env.SMS_PROVIDER || "console",
  defaultCountryCode: process.env.DEFAULT_COUNTRY_CODE || "+977",
  cookieSecure: process.env.COOKIE_SECURE === "true"
};