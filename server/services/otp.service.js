import { OtpCode } from "../models/OtpCode.js";
import { env } from "../config/env.js";
import { sendOtpSms, verifyOtpSms } from "./sms.providers.js";

function generateOtp(length) {
  let code = "";
  for (let i = 0; i < length; i++) {
    code += Math.floor(Math.random() * 10);
  }
  return code;
}

export async function createAndSendOtp(phone) {
  const latest = await OtpCode.findOne({ phone }).sort({ createdAt: -1 });

  if (latest) {
    const diffSec = Math.floor((Date.now() - new Date(latest.createdAt).getTime()) / 1000);
    if (diffSec < env.otpResendSeconds) {
      throw new Error(`Please wait ${env.otpResendSeconds - diffSec}s before resending OTP`);
    }
  }

  const code = generateOtp(env.otpLength);
  const expiresAt = new Date(Date.now() + env.otpExpiresSeconds * 1000);

  if (env.smsProvider === "twilio-verify") {
    await sendOtpSms({ phone, code });
    await OtpCode.create({ phone, code: "twilio-managed", expiresAt });
    return true;
  }

  await OtpCode.create({ phone, code, expiresAt });
  await sendOtpSms({ phone, code });
  return true;
}

export async function verifyOtp(phone, code) {
  if (env.smsProvider === "twilio-verify") {
    return verifyOtpSms({ phone, code });
  }

  const otp = await OtpCode.findOne({ phone, verified: false }).sort({ createdAt: -1 });
  if (!otp) return false;
  if (otp.expiresAt.getTime() < Date.now()) return false;

  if (otp.code !== code) {
    otp.attempts += 1;
    await otp.save();
    return false;
  }

  otp.verified = true;
  await otp.save();
  return true;
}