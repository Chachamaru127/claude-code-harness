import React from 'react';
/**
 * @description Wraps the native `<video>` element to include video in your component that is synchronized with Remotion's time.
 * @see [Documentation](https://www.remotion.dev/docs/html5-video)
 */
export declare const Html5Video: React.ForwardRefExoticComponent<Omit<import("./props").NativeVideoProps & {
    name?: string;
    volume?: import("../volume-prop.js").VolumeProp;
    playbackRate?: number;
    acceptableTimeShiftInSeconds?: number;
    allowAmplificationDuringRender?: boolean;
    useWebAudioApi?: boolean;
    toneFrequency?: number;
    pauseWhenBuffering?: boolean;
    showInTimeline?: boolean;
    delayRenderTimeoutInMilliseconds?: number;
    loopVolumeCurveBehavior?: import("../index.js").LoopVolumeCurveBehavior;
    delayRenderRetries?: number;
    onError?: (err: Error) => void;
    onAutoPlayError?: null | (() => void);
    audioStreamIndex?: number;
} & Partial<import("./props").CommonVideoProps> & {
    /**
     * @deprecated For internal use only
     */
    readonly stack?: string;
}, "ref"> & React.RefAttributes<HTMLVideoElement>>;
/**
 * @deprecated This component has been renamed to `Html5Video`.
 * @see [Documentation](https://remotion.dev/docs/mediabunny/new-video)
 */
export declare const Video: React.ForwardRefExoticComponent<Omit<import("./props").NativeVideoProps & {
    name?: string;
    volume?: import("../volume-prop.js").VolumeProp;
    playbackRate?: number;
    acceptableTimeShiftInSeconds?: number;
    allowAmplificationDuringRender?: boolean;
    useWebAudioApi?: boolean;
    toneFrequency?: number;
    pauseWhenBuffering?: boolean;
    showInTimeline?: boolean;
    delayRenderTimeoutInMilliseconds?: number;
    loopVolumeCurveBehavior?: import("../index.js").LoopVolumeCurveBehavior;
    delayRenderRetries?: number;
    onError?: (err: Error) => void;
    onAutoPlayError?: null | (() => void);
    audioStreamIndex?: number;
} & Partial<import("./props").CommonVideoProps> & {
    /**
     * @deprecated For internal use only
     */
    readonly stack?: string;
}, "ref"> & React.RefAttributes<HTMLVideoElement>>;
