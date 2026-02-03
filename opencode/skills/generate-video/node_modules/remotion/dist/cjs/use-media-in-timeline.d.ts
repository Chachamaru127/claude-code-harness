import type { LoopDisplay } from './CompositionManager.js';
import type { VolumeProp } from './volume-prop.js';
export declare const useBasicMediaInTimeline: ({ volume, mediaVolume, mediaType, src, displayName, trimBefore, trimAfter, playbackRate, }: {
    volume: VolumeProp | undefined;
    mediaVolume: number;
    mediaType: "audio" | "video";
    src: string | undefined;
    displayName: string | null;
    trimBefore: number | undefined;
    trimAfter: number | undefined;
    playbackRate: number;
}) => {
    volumes: string | number;
    duration: number;
    doesVolumeChange: boolean;
    nonce: number;
    rootId: string;
    isStudio: boolean;
    finalDisplayName: string;
};
export declare const useMediaInTimeline: ({ volume, mediaVolume, src, mediaType, playbackRate, displayName, id, stack, showInTimeline, premountDisplay, postmountDisplay, loopDisplay, }: {
    volume: VolumeProp | undefined;
    mediaVolume: number;
    src: string | undefined;
    mediaType: "audio" | "video";
    playbackRate: number;
    displayName: string | null;
    id: string;
    stack: string | null;
    showInTimeline: boolean;
    premountDisplay: number | null;
    postmountDisplay: number | null;
    loopDisplay: LoopDisplay | undefined;
}) => void;
