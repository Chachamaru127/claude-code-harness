import type { AudioHTMLAttributes } from 'react';
import React from 'react';
import type { SharedElementSourceNode } from './shared-element-source-node.js';
/**
 * This functionality of Remotion will keep a certain amount
 * of <audio> tags pre-mounted and by default filled with an empty audio track.
 * If the user interacts, the empty audio will be played.
 * If one of Remotions <Html5Audio /> tags get mounted, the audio will not be rendered at this location, but into one of the prerendered audio tags.
 *
 * This helps with autoplay issues on iOS Safari and soon other browsers,
 * which only allow audio playback upon user interaction.
 *
 * The behavior can be disabled by passing `0` as the number of shared audio tracks.
 */
type AudioElem = {
    id: number;
    props: AudioHTMLAttributes<HTMLAudioElement>;
    el: React.RefObject<HTMLAudioElement | null>;
    audioId: string;
    mediaElementSourceNode: SharedElementSourceNode | null;
    premounting: boolean;
    postmounting: boolean;
    audioMounted: boolean;
    cleanupOnMediaTagUnmount: () => void;
};
type SharedContext = {
    registerAudio: (options: {
        aud: AudioHTMLAttributes<HTMLAudioElement>;
        audioId: string;
        premounting: boolean;
        postmounting: boolean;
    }) => AudioElem;
    unregisterAudio: (id: number) => void;
    updateAudio: (options: {
        id: number;
        aud: AudioHTMLAttributes<HTMLAudioElement>;
        audioId: string;
        premounting: boolean;
        postmounting: boolean;
    }) => void;
    playAllAudios: () => void;
    numberOfAudioTags: number;
    audioContext: AudioContext | null;
};
export declare const SharedAudioContext: React.Context<SharedContext | null>;
export declare const SharedAudioContextProvider: React.FC<{
    readonly numberOfAudioTags: number;
    readonly children: React.ReactNode;
    readonly audioLatencyHint: AudioContextLatencyCategory;
    readonly audioEnabled: boolean;
}>;
export declare const useSharedAudio: ({ aud, audioId, premounting, postmounting, }: {
    aud: AudioHTMLAttributes<HTMLAudioElement>;
    audioId: string;
    premounting: boolean;
    postmounting: boolean;
}) => AudioElem;
export {};
