export declare const makeSharedElementSourceNode: ({ audioContext, ref, }: {
    audioContext: AudioContext;
    ref: React.RefObject<HTMLAudioElement | null>;
}) => {
    attemptToConnect: () => void;
    get: () => MediaElementAudioSourceNode;
    cleanup: () => void;
};
export type SharedElementSourceNode = ReturnType<typeof makeSharedElementSourceNode>;
