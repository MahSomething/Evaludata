/**
 * Logger seguro — nunca expoe campos sensiveis em logs
 * 
 * Regras:
 * - Nunca logar objects completos de utilizador, sessao, ou env
 * - Logar apenas IDs para referencia
 * - Campos sensiveis sao automaticamente redactados
 * - Em producao, apenas logar niveis WARN e ERROR
 */

const SENSITIVE_FIELDS = [
  "password",
  "senha",
  "token",
  "secret",
  "key",
  "apiKey",
  "api_key",
  "accessToken",
  "access_token",
  "refreshToken",
  "refresh_token",
  "serviceRole",
  "service_role",
  "authorization",
  "cookie",
  "session",
  "otp",
  "codigo",
  "nuit",
  "email",
  "telemovel",
  "telefone",
  "contacto",
];

function redactSensitive(data: unknown): unknown {
  if (data === null || data === undefined) {
    return data;
  }

  if (typeof data === "string") {
    // Se a string parece um token ou secret, redact completamente
    if (
      data.startsWith("eyJ") || // JWT
      data.startsWith("sk-") || // Secret key
      data.startsWith("pk-") || // Public key
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(data) // UUID
    ) {
      return "[REDACTED]";
    }
    return data;
  }

  if (Array.isArray(data)) {
    return data.map(redactSensitive);
  }

  if (typeof data === "object") {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(data)) {
      const lowerKey = key.toLowerCase();
      if (SENSITIVE_FIELDS.some((field) => lowerKey.includes(field))) {
        result[key] = "[REDACTED]";
      } else {
        result[key] = redactSensitive(value);
      }
    }
    return result;
  }

  return data;
}

type LogLevel = "debug" | "info" | "warn" | "error";

function shouldLog(level: LogLevel): boolean {
  const env = process.env.NODE_ENV || "development";
  const minLevel = process.env.LOG_LEVEL || (env === "production" ? "warn" : "debug");

  const levels: Record<LogLevel, number> = {
    debug: 0,
    info: 1,
    warn: 2,
    error: 3,
  };

  return levels[level] >= levels[minLevel as LogLevel];
}

function formatLog(
  level: LogLevel,
  message: string,
  context?: Record<string, unknown>
): string {
  const timestamp = new Date().toISOString();
  const safeContext = context ? redactSensitive(context) : undefined;

  return JSON.stringify({
    timestamp,
    level: level.toUpperCase(),
    message,
    ...(safeContext ? { context: safeContext } : {}),
  });
}

export const logger = {
  debug: (message: string, context?: Record<string, unknown>) => {
    if (shouldLog("debug")) {
      console.log(formatLog("debug", message, context));
    }
  },

  info: (message: string, context?: Record<string, unknown>) => {
    if (shouldLog("info")) {
      console.log(formatLog("info", message, context));
    }
  },

  warn: (message: string, context?: Record<string, unknown>) => {
    if (shouldLog("warn")) {
      console.warn(formatLog("warn", message, context));
    }
  },

  error: (message: string, error?: Error, context?: Record<string, unknown>) => {
    if (shouldLog("error")) {
      const safeContext = {
        ...context,
        errorName: error?.name,
        errorMessage: error?.message, // Cuidado: pode conter dados sensiveis
      };
      console.error(formatLog("error", message, safeContext));
    }
  },
};

/**
 * Helper para logar acoes de utilizador (auditoria)
 * Sempre loga, independentemente do nivel configurado
 */
export function logAudit(
  action: string,
  userId: string,
  details: Record<string, unknown>
): void {
  console.log(
    JSON.stringify({
      timestamp: new Date().toISOString(),
      level: "AUDIT",
      action,
      userId,
      details: redactSensitive(details),
    })
  );
}
