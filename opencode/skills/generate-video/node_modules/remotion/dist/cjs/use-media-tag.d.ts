import type { RefObject } from 'react';
export declare const useMediaTag: ({ mediaRef, id, mediaType, onAutoPlayError, isPremounting, isPostmounting, }: {
    mediaRef: RefObject<HTMLAudioElement | HTMLVideoElement | null>;
    id: string;
    mediaType: "audio" | "video";
    onAutoPlayError: null | (() => void);
    isPremounting: boolean;
    isPostmounting: boolean;
}) => void;
