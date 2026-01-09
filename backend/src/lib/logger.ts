type LogLevel = 'info' | 'warn' | 'error';

interface LogContext {
  [key: string]: string | number | boolean | undefined;
}

function formatLog(level: LogLevel, message: string, context?: LogContext): string {
  const timestamp = new Date().toISOString();
  const contextStr = context ? ` ${JSON.stringify(context)}` : '';
  return `[${timestamp}] ${level.toUpperCase()} ${message}${contextStr}`;
}

export const logger = {
  info: (message: string, context?: LogContext) => {
    console.log(formatLog('info', message, context));
  },
  warn: (message: string, context?: LogContext) => {
    console.warn(formatLog('warn', message, context));
  },
  error: (message: string, context?: LogContext) => {
    console.error(formatLog('error', message, context));
  },
};
