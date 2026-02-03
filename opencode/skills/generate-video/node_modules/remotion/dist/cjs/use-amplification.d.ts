import { type RefObject } from 'react';
import type { SharedElementSourceNode } from './audio/shared-element-source-node';
import type { LogLevel } from './log';
type AudioItems = {
    gainNode: GainNode;
};
/**
 * [1] Bug case: In Safari, you cannot combine playbackRate and volume !== 1.
 * If that is the case, volume will not be applied.
 */
export declare const useVolume: ({ mediaRef, volume, logLevel, source, shouldUseWebAudioApi, }: {
    mediaRef: RefObject<HTMLAudioElement | HTMLVideoElement | null>;
    source: SharedElementSourceNode | null;
    volume: number;
    logLevel: LogLevel;
    shouldUseWebAudioApi: boolean;
}) => RefObject<AudioItems | null>;
export {};
