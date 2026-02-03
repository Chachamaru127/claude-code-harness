import type { LogLevel } from '../log';
export declare const useSingletonAudioContext: ({ logLevel, latencyHint, audioEnabled, }: {
    logLevel: LogLevel;
    latencyHint: AudioContextLatencyCategory;
    audioEnabled: boolean;
}) => AudioContext | null;
