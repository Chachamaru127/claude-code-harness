export declare const logLevels: readonly ["trace", "verbose", "info", "warn", "error"];
export type LogLevel = (typeof logLevels)[number];
export declare const isEqualOrBelowLogLevel: (currentLevel: LogLevel, level: LogLevel) => boolean;
type Options = {
    logLevel: LogLevel;
    tag: string | null;
};
export declare const Log: {
    trace: (options: Options, message?: any, ...optionalParams: any[]) => void;
    verbose: (options: Options, message?: any, ...optionalParams: any[]) => void;
    info: (options: Options, message?: any, ...optionalParams: any[]) => void;
    warn: (options: Options, message?: any, ...optionalParams: any[]) => void;
    error: (options: Options, message?: any, ...optionalParams: any[]) => void;
};
export {};
