import type { LogLevel } from './log.js';
import type { RemotionEnvironment } from './remotion-environment-context.js';
export type DelayRenderScope = {
    remotion_renderReady: boolean;
    remotion_delayRenderTimeouts: {
        [key: string]: {
            label: string | null;
            timeout: number | Timer;
            startTime: number;
        };
    };
    remotion_puppeteerTimeout: number;
    remotion_attempt: number;
    remotion_delayRenderHandles: number[];
    remotion_cancelledError?: string;
};
export declare const DELAY_RENDER_CALLSTACK_TOKEN = "The delayRender was called:";
export declare const DELAY_RENDER_RETRIES_LEFT = "Retries left: ";
export declare const DELAY_RENDER_RETRY_TOKEN = "- Rendering the frame will be retried.";
export declare const DELAY_RENDER_CLEAR_TOKEN = "handle was cleared after";
export type DelayRenderOptions = {
    timeoutInMilliseconds?: number;
    retries?: number;
};
/**
 * Internal function that accepts environment as parameter.
 * This allows useDelayRender to control its own environment source.
 * @private
 */
export declare const delayRenderInternal: ({ scope, environment, label, options, }: {
    scope: DelayRenderScope;
    environment: RemotionEnvironment;
    label: string | null;
    options: DelayRenderOptions;
}) => number;
export declare const delayRender: (label?: string, options?: DelayRenderOptions) => number;
/**
 * Internal function that accepts environment as parameter.
 * @private
 */
export declare const continueRenderInternal: ({ scope, handle, environment, logLevel, }: {
    scope: DelayRenderScope;
    handle: number;
    environment: RemotionEnvironment;
    logLevel: LogLevel;
}) => void;
export declare const continueRender: (handle: number) => void;
