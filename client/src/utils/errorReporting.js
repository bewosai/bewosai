// Error alerts (Sentry). Off until VITE_SENTRY_DSN is set in the Vercel
// project's environment variables; then any crash in a user's browser —
// stack trace, page and browser, no form data — reaches the Sentry project,
// which emails its owner.
import * as Sentry from "@sentry/react";

const DSN = import.meta.env.VITE_SENTRY_DSN;

export function installErrorReporting() {
  if (!DSN || import.meta.env.DEV) return;
  Sentry.init({
    dsn: DSN,
    environment: "production",
    sendDefaultPii: false,
    tracesSampleRate: 0, // errors only; performance tracing would eat the free quota
  });
}

export const ErrorBoundary = Sentry.ErrorBoundary;
