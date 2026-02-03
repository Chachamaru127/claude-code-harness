import type { RefObject } from 'react';
export declare const useMediaPlayback: ({ mediaRef, src, mediaType, playbackRate: localPlaybackRate, onlyWarnForMediaSeekingError, acceptableTimeshift, pauseWhenBuffering, isPremounting, isPostmounting, onAutoPlayError, }: {
    mediaRef: RefObject<HTMLVideoElement | HTMLAudioElement | null>;
    src: string | undefined;
    mediaType: "audio" | "video";
    playbackRate: number;
    onlyWarnForMediaSeekingError: boolean;
    acceptableTimeshift: number | null;
    pauseWhenBuffering: boolean;
    isPremounting: boolean;
    isPostmounting: boolean;
    onAutoPlayError: null | (() => void);
}) => void;
