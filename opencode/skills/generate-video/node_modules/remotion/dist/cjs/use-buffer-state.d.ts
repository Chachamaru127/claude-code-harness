export type DelayPlaybackHandle = {
    unblock: () => void;
};
export type UseBufferState = {
    delayPlayback: () => DelayPlaybackHandle;
};
export declare const useBufferState: () => UseBufferState;
