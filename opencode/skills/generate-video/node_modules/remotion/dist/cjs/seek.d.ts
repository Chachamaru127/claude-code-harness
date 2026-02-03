import type { LogLevel } from './log';
export declare const seek: ({ mediaRef, time, logLevel, why, mountTime, }: {
    mediaRef: HTMLVideoElement | HTMLAudioElement;
    time: number;
    logLevel: LogLevel;
    why: string;
    mountTime: number;
}) => number;
