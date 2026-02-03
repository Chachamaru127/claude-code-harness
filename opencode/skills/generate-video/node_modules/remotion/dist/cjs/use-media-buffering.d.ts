import type React from 'react';
import type { LogLevel } from './log';
export declare const useMediaBuffering: ({ element, shouldBuffer, isPremounting, isPostmounting, logLevel, mountTime, src, }: {
    element: React.RefObject<HTMLVideoElement | HTMLAudioElement | null>;
    shouldBuffer: boolean;
    isPremounting: boolean;
    isPostmounting: boolean;
    logLevel: LogLevel;
    mountTime: number;
    src: string | null;
}) => boolean;
