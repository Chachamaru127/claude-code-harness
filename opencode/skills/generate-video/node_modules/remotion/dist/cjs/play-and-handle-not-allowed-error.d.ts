import type { RefObject } from 'react';
import { type LogLevel } from './log';
export declare const playAndHandleNotAllowedError: ({ mediaRef, mediaType, onAutoPlayError, logLevel, mountTime, reason, isPlayer, }: {
    mediaRef: RefObject<HTMLVideoElement | HTMLAudioElement | null>;
    mediaType: "audio" | "video";
    onAutoPlayError: null | (() => void);
    logLevel: LogLevel;
    mountTime: number;
    reason: string;
    isPlayer: boolean;
}) => void;
