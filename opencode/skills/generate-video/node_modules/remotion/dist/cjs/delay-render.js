"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.continueRender = exports.continueRenderInternal = exports.delayRender = exports.delayRenderInternal = exports.DELAY_RENDER_CLEAR_TOKEN = exports.DELAY_RENDER_RETRY_TOKEN = exports.DELAY_RENDER_RETRIES_LEFT = exports.DELAY_RENDER_CALLSTACK_TOKEN = void 0;
const cancel_render_js_1 = require("./cancel-render.js");
const get_remotion_environment_js_1 = require("./get-remotion-environment.js");
const log_js_1 = require("./log.js");
const truthy_js_1 = require("./truthy.js");
if (typeof window !== 'undefined') {
    window.remotion_renderReady = false;
    if (!window.remotion_delayRenderTimeouts) {
        window.remotion_delayRenderTimeouts = {};
    }
    window.remotion_delayRenderHandles = [];
}
exports.DELAY_RENDER_CALLSTACK_TOKEN = 'The delayRender was called:';
exports.DELAY_RENDER_RETRIES_LEFT = 'Retries left: ';
exports.DELAY_RENDER_RETRY_TOKEN = '- Rendering the frame will be retried.';
exports.DELAY_RENDER_CLEAR_TOKEN = 'handle was cleared after';
const defaultTimeout = 30000;
/**
 * Internal function that accepts environment as parameter.
 * This allows useDelayRender to control its own environment source.
 * @private
 */
const delayRenderInternal = ({ scope, environment, label, options, }) => {
    var _a, _b, _c, _d, _e;
    if (typeof label !== 'string' && label !== null) {
        throw new Error('The label parameter of delayRender() must be a string or undefined, got: ' +
            JSON.stringify(label));
    }
    const handle = Math.random();
    scope.remotion_delayRenderHandles.push(handle);
    const called = (_b = (_a = Error().stack) === null || _a === void 0 ? void 0 : _a.replace(/^Error/g, '')) !== null && _b !== void 0 ? _b : '';
    if (environment.isRendering) {
        const timeoutToUse = ((_d = (_c = options === null || options === void 0 ? void 0 : options.timeoutInMilliseconds) !== null && _c !== void 0 ? _c : scope.remotion_puppeteerTimeout) !== null && _d !== void 0 ? _d : defaultTimeout) - 2000;
        const retriesLeft = ((_e = options === null || options === void 0 ? void 0 : options.retries) !== null && _e !== void 0 ? _e : 0) - (scope.remotion_attempt - 1);
        scope.remotion_delayRenderTimeouts[handle] = {
            label: label !== null && label !== void 0 ? label : null,
            startTime: Date.now(),
            timeout: setTimeout(() => {
                const message = [
                    `A delayRender()`,
                    label ? `"${label}"` : null,
                    `was called but not cleared after ${timeoutToUse}ms. See https://remotion.dev/docs/timeout for help.`,
                    retriesLeft > 0 ? exports.DELAY_RENDER_RETRIES_LEFT + retriesLeft : null,
                    retriesLeft > 0 ? exports.DELAY_RENDER_RETRY_TOKEN : null,
                    exports.DELAY_RENDER_CALLSTACK_TOKEN,
                    called,
                ]
                    .filter(truthy_js_1.truthy)
                    .join(' ');
                // in client-side rendering, don't throw (would be uncaught from setTimeout)
                if (environment.isClientSideRendering) {
                    scope.remotion_cancelledError = (0, cancel_render_js_1.getErrorStackWithMessage)(Error(message));
                }
                else {
                    (0, cancel_render_js_1.cancelRenderInternal)(scope, Error(message));
                }
            }, timeoutToUse),
        };
    }
    scope.remotion_renderReady = false;
    return handle;
};
exports.delayRenderInternal = delayRenderInternal;
/*
 * @description Call this function to signal that a frame should not be rendered until an asynchronous task (such as data fetching) is complete. Use continueRender(handle) to proceed with rendering once the task is complete.
 * @see [Documentation](https://remotion.dev/docs/delay-render)
 */
const delayRender = (label, options) => {
    if (typeof window === 'undefined') {
        return Math.random();
    }
    return (0, exports.delayRenderInternal)({
        scope: window,
        environment: (0, get_remotion_environment_js_1.getRemotionEnvironment)(),
        label: label !== null && label !== void 0 ? label : null,
        options: options !== null && options !== void 0 ? options : {},
    });
};
exports.delayRender = delayRender;
/**
 * Internal function that accepts environment as parameter.
 * @private
 */
const continueRenderInternal = ({ scope, handle, environment, logLevel, }) => {
    if (typeof handle === 'undefined') {
        throw new TypeError('The continueRender() method must be called with a parameter that is the return value of delayRender(). No value was passed.');
    }
    if (typeof handle !== 'number') {
        throw new TypeError('The parameter passed into continueRender() must be the return value of delayRender() which is a number. Got: ' +
            JSON.stringify(handle));
    }
    scope.remotion_delayRenderHandles = scope.remotion_delayRenderHandles.filter((h) => {
        if (h === handle) {
            if (environment.isRendering && scope !== undefined) {
                if (!scope.remotion_delayRenderTimeouts[handle]) {
                    return false;
                }
                const { label, startTime, timeout } = scope.remotion_delayRenderTimeouts[handle];
                clearTimeout(timeout);
                const message = [
                    label ? `"${label}"` : 'A handle',
                    exports.DELAY_RENDER_CLEAR_TOKEN,
                    `${Date.now() - startTime}ms`,
                ]
                    .filter(truthy_js_1.truthy)
                    .join(' ');
                log_js_1.Log.verbose({ logLevel, tag: 'delayRender()' }, message);
                delete scope.remotion_delayRenderTimeouts[handle];
            }
            return false;
        }
        return true;
    });
    if (scope.remotion_delayRenderHandles.length === 0) {
        scope.remotion_renderReady = true;
    }
};
exports.continueRenderInternal = continueRenderInternal;
/*
 * @description Unblock a render that has been blocked by delayRender().
 * @see [Documentation](https://remotion.dev/docs/continue-render)
 */
const continueRender = (handle) => {
    var _a;
    if (typeof window === 'undefined') {
        return;
    }
    (0, exports.continueRenderInternal)({
        scope: window,
        handle,
        environment: (0, get_remotion_environment_js_1.getRemotionEnvironment)(),
        logLevel: (_a = window.remotion_logLevel) !== null && _a !== void 0 ? _a : 'info',
    });
};
exports.continueRender = continueRender;
