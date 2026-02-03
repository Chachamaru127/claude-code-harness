import type { MutableRefObject } from 'react';
import React from 'react';
import { type PlayableMediaTag } from './timeline-position-state';
export type TimelineContextValue = {
    frame: Record<string, number>;
    playing: boolean;
    rootId: string;
    playbackRate: number;
    imperativePlaying: MutableRefObject<boolean>;
    setPlaybackRate: (u: React.SetStateAction<number>) => void;
    audioAndVideoTags: MutableRefObject<PlayableMediaTag[]>;
};
export type SetTimelineContextValue = {
    setFrame: (u: React.SetStateAction<Record<string, number>>) => void;
    setPlaying: (u: React.SetStateAction<boolean>) => void;
};
export declare const SetTimelineContext: React.Context<SetTimelineContextValue>;
export declare const TimelineContext: React.Context<TimelineContextValue>;
export declare const TimelineContextProvider: React.FC<{
    readonly children: React.ReactNode;
    readonly frameState: Record<string, number> | null;
}>;
