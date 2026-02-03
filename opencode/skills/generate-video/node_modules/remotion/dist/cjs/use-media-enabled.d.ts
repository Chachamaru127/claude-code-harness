export declare const useVideoEnabled: () => boolean;
export declare const useAudioEnabled: () => boolean;
export declare const MediaEnabledProvider: ({ children, videoEnabled, audioEnabled, }: {
    readonly children: React.ReactNode;
    readonly videoEnabled: boolean | null;
    readonly audioEnabled: boolean | null;
}) => import("react/jsx-runtime").JSX.Element;
