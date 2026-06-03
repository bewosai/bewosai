import twilio from "twilio";
import { env } from "../config/env.js";

const client =
  env.twilioAccountSid && env.twilioAuthToken
    ? twilio(env.twilioAccountSid, env.twilioAuthToken)
    : null;

export async function sendOtpSms({ phone, code }) {
  if (env.smsProvider === "console") {
    console.log(`OTP for ${phone}: ${code}`);
    return { provider: "console", sent: true };
  }

  if (env.smsProvider === "twilio-verify") {
    if (!client || !env.twilioVerifyServiceSid) {
      throw new Error("Twilio Verify not configured");
    }

    await client.verify.v2
      .services(env.twilioVerifyServiceSid)
      .verifications.create({ to: phone, channel: "sms" });

    return { provider: "twilio-verify", sent: true };
  }

  throw new Error("Unsupported SMS provider");
}

export async function verifyOtpSms({ phone, code }) {
  if (env.smsProvider === "twilio-verify") {
    if (!client || !env.twilioVerifyServiceSid) {
      throw new Error("Twilio Verify not configured");
    }

    const check = await client.verify.v2
      .services(env.twilioVerifyServiceSid)
      .verificationChecks.create({ to: phone, code });

    return check.status === "approved";
  }

  return false;
}