import type { MutableRefObject } from 'react';
export type PlayableMediaTag = {
    play: (reason: string) => void;
    id: string;
};
type CurrentTimePerComposition = Record<string, number>;
export declare const persistCurrentFrame: (time: CurrentTimePerComposition) => void;
export declare const getInitialFrameState: () => CurrentTimePerComposition;
export declare const getFrameForComposition: (composition: string) => number;
export declare const useTimelinePosition: () => number;
export declare const useTimelineSetFrame: () => ((u: React.SetStateAction<Record<string, number>>) => void);
type PlayingReturnType = readonly [
    boolean,
    (u: React.SetStateAction<boolean>) => void,
    MutableRefObject<boolean>
];
export declare const usePlayingState: () => PlayingReturnType;
export {};
