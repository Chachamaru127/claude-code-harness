import React from 'react';
import type { LogLevel } from './log.js';
export declare const RemotionRootContexts: React.FC<{
    readonly children: React.ReactNode;
    readonly numberOfAudioTags: number;
    readonly logLevel: LogLevel;
    readonly audioLatencyHint: AudioContextLatencyCategory;
    readonly videoEnabled: boolean;
    readonly audioEnabled: boolean;
    readonly frameState: Record<string, number> | null;
    readonly nonceContextSeed: number;
}>;
