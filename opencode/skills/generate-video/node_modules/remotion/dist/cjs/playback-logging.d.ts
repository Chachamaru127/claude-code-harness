import { type LogLevel } from './log';
export declare const playbackLogging: ({ logLevel, tag, message, mountTime, }: {
    logLevel: LogLevel;
    tag: string;
    message: string;
    mountTime: number | null;
}) => void;
