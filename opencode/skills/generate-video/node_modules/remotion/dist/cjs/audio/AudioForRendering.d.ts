import type { ForwardRefExoticComponent, RefAttributes } from 'react';
import React from 'react';
import type { RemotionAudioProps } from './props.js';
type AudioForRenderingProps = RemotionAudioProps & {
    readonly onDuration: (src: string, durationInSeconds: number) => void;
    readonly onNativeError: React.ReactEventHandler<HTMLAudioElement>;
};
export declare const AudioForRendering: ForwardRefExoticComponent<AudioForRenderingProps & RefAttributes<HTMLAudioElement>>;
export {};
