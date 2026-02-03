import type { LogLevel } from './log';
import React = require('react');
export type LoggingContextValue = {
    logLevel: LogLevel | null;
    mountTime: number;
};
export declare const LogLevelContext: React.Context<LoggingContextValue>;
export declare const useLogLevel: () => LogLevel;
export declare const useMountTime: () => number;
