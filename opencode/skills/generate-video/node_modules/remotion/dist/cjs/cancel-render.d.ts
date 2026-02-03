import type { DelayRenderScope } from './delay-render.js';
export declare const getErrorStackWithMessage: (error: Error) => string;
/**
 * Internal function that accepts scope as parameter.
 * This allows useDelayRender to control its own scope source.
 * @private
 */
export declare function cancelRenderInternal(scope: DelayRenderScope | undefined, err: unknown): never;
export declare function cancelRender(err: unknown): never;
