import React from 'react';
import type { LoopDisplay } from './CompositionManager.js';
export type AbsoluteFillLayout = {
    layout?: 'absolute-fill';
    premountFor?: number;
    postmountFor?: number;
    style?: React.CSSProperties;
    styleWhilePremounted?: React.CSSProperties;
    styleWhilePostmounted?: React.CSSProperties;
    className?: string;
};
export type LayoutAndStyle = AbsoluteFillLayout | {
    layout: 'none';
};
export type SequencePropsWithoutDuration = {
    readonly children: React.ReactNode;
    readonly width?: number;
    readonly height?: number;
    readonly from?: number;
    readonly name?: string;
    readonly showInTimeline?: boolean;
    /**
     * @deprecated For internal use only.
     */
    readonly _remotionInternalLoopDisplay?: LoopDisplay;
    /**
     * @deprecated For internal use only.
     */
    readonly _remotionInternalPremountDisplay?: number | null;
    /**
     * @deprecated For internal use only.
     */
    readonly _remotionInternalPostmountDisplay?: number | null;
    /**
     * @deprecated For internal use only.
     */
    readonly _remotionInternalStack?: string;
    /**
     * @deprecated For internal use only.
     */
    readonly _remotionInternalIsPremounting?: boolean;
    /**
     * @deprecated For internal use only.
     */
    readonly _remotionInternalIsPostmounting?: boolean;
} & LayoutAndStyle;
export type SequenceProps = {
    readonly durationInFrames?: number;
} & SequencePropsWithoutDuration;
export declare const Sequence: React.ForwardRefExoticComponent<SequenceProps & React.RefAttributes<HTMLDivElement>>;
