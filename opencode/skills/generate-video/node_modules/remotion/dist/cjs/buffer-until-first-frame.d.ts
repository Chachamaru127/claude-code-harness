import type { LogLevel } from './log';
export declare const useBufferUntilFirstFrame: ({ mediaRef, mediaType, onVariableFpsVideoDetected, pauseWhenBuffering, logLevel, mountTime, }: {
    mediaRef: React.RefObject<HTMLVideoElement | HTMLAudioElement | null>;
    mediaType: "video" | "audio";
    onVariableFpsVideoDetected: () => void;
    pauseWhenBuffering: boolean;
    logLevel: LogLevel;
    mountTime: number | null;
}) => {
    isBuffering: () => boolean;
    bufferUntilFirstFrame: (requestedTime: number) => void;
};
