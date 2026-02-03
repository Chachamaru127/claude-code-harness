import React from 'react';
import type { RemotionMainAudioProps } from './props.js';
/**
 * @description With this component, you can add audio to your video. All audio formats which are supported by Chromium are supported by the component.
 * @see [Documentation](https://remotion.dev/docs/html5-audio)
 */
export declare const Html5Audio: React.ForwardRefExoticComponent<Omit<import("./props.js").NativeAudioProps & {
    name?: string;
    volume?: import("../volume-prop.js").VolumeProp;
    playbackRate?: number;
    acceptableTimeShiftInSeconds?: number;
    allowAmplificationDuringRender?: boolean;
    _remotionInternalNeedsDurationCalculation?: boolean;
    _remotionInternalNativeLoopPassed?: boolean;
    toneFrequency?: number;
    useWebAudioApi?: boolean;
    pauseWhenBuffering?: boolean;
    showInTimeline?: boolean;
    delayRenderTimeoutInMilliseconds?: number;
    delayRenderRetries?: number;
    loopVolumeCurveBehavior?: import("./use-audio-frame.js").LoopVolumeCurveBehavior;
    onError?: (err: Error) => void;
    audioStreamIndex?: number;
} & RemotionMainAudioProps & {
    /**
     * @deprecated For internal use only
     */
    readonly stack?: string;
}, "ref"> & React.RefAttributes<HTMLAudioElement>>;
/**
 * @deprecated This component has been renamed to `Html5Audio`.
 * @see [Documentation](https://remotion.dev/docs/mediabunny/new-video)
 */
export declare const Audio: React.ForwardRefExoticComponent<Omit<import("./props.js").NativeAudioProps & {
    name?: string;
    volume?: import("../volume-prop.js").VolumeProp;
    playbackRate?: number;
    acceptableTimeShiftInSeconds?: number;
    allowAmplificationDuringRender?: boolean;
    _remotionInternalNeedsDurationCalculation?: boolean;
    _remotionInternalNativeLoopPassed?: boolean;
    toneFrequency?: number;
    useWebAudioApi?: boolean;
    pauseWhenBuffering?: boolean;
    showInTimeline?: boolean;
    delayRenderTimeoutInMilliseconds?: number;
    delayRenderRetries?: number;
    loopVolumeCurveBehavior?: import("./use-audio-frame.js").LoopVolumeCurveBehavior;
    onError?: (err: Error) => void;
    audioStreamIndex?: number;
} & RemotionMainAudioProps & {
    /**
     * @deprecated For internal use only
     */
    readonly stack?: string;
}, "ref"> & React.RefAttributes<HTMLAudioElement>>;
