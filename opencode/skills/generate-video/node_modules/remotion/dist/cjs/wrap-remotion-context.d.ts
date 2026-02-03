import React from 'react';
export declare function useRemotionContexts(): {
    compositionManagerCtx: import("./CompositionManagerContext.js").CompositionManagerContext;
    timelineContext: import("./TimelineContext.js").TimelineContextValue;
    setTimelineContext: import("./TimelineContext.js").SetTimelineContextValue;
    sequenceContext: import("./SequenceContext.js").SequenceContextType | null;
    nonceContext: import("./nonce.js").TNonceContext;
    canUseRemotionHooksContext: boolean;
    preloadContext: {
        [x: string]: string;
    };
    resolveCompositionContext: {
        [x: string]: ({
            type: "loading";
        } | {
            type: "success";
            result: import("./video-config.js").VideoConfig;
        } | {
            type: "success-and-refreshing";
            result: import("./video-config.js").VideoConfig;
        } | {
            type: "error";
            error: Error;
        }) | undefined;
    } | null;
    renderAssetManagerContext: import("./RenderAssetManager.js").RenderAssetManagerContext;
    sequenceManagerContext: import("./SequenceManager.js").SequenceManagerContext;
    bufferManagerContext: {
        addBlock: (block: {
            id: string;
        }) => {
            unblock: () => void;
        };
        listenForBuffering: (callback: () => void) => {
            remove: () => void;
        };
        listenForResume: (callback: () => void) => {
            remove: () => void;
        };
        buffering: React.MutableRefObject<boolean>;
    } | null;
    logLevelContext: import("./log-level-context.js").LoggingContextValue;
};
export interface RemotionContextProviderProps {
    readonly contexts: ReturnType<typeof useRemotionContexts>;
    readonly children: React.ReactNode;
}
export declare const RemotionContextProvider: (props: RemotionContextProviderProps) => import("react/jsx-runtime.js").JSX.Element;
