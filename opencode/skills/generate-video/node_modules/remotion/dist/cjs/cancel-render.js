"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getErrorStackWithMessage = void 0;
exports.cancelRenderInternal = cancelRenderInternal;
exports.cancelRender = cancelRender;
// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error/stack
const getErrorStackWithMessage = (error) => {
    var _a;
    const stack = (_a = error.stack) !== null && _a !== void 0 ? _a : '';
    return stack.startsWith('Error:') ? stack : `${error.message}\n${stack}`;
};
exports.getErrorStackWithMessage = getErrorStackWithMessage;
const isErrorLike = (err) => {
    if (err instanceof Error) {
        return true;
    }
    if (err === null) {
        return false;
    }
    if (typeof err !== 'object') {
        return false;
    }
    if (!('stack' in err)) {
        return false;
    }
    // eslint-disable-next-line @typescript-eslint/prefer-ts-expect-error
    // @ts-ignore we just asserted
    if (typeof err.stack !== 'string') {
        return false;
    }
    if (!('message' in err)) {
        return false;
    }
    // eslint-disable-next-line @typescript-eslint/prefer-ts-expect-error
    // @ts-ignore we just asserted
    if (typeof err.message !== 'string') {
        return false;
    }
    return true;
};
/**
 * Internal function that accepts scope as parameter.
 * This allows useDelayRender to control its own scope source.
 * @private
 */
function cancelRenderInternal(scope, err) {
    let error;
    if (isErrorLike(err)) {
        error = err;
        if (!error.stack) {
            error.stack = new Error(error.message).stack;
        }
    }
    else if (typeof err === 'string') {
        error = Error(err);
    }
    else {
        error = Error('Rendering was cancelled');
    }
    if (scope) {
        scope.remotion_cancelledError = (0, exports.getErrorStackWithMessage)(error);
    }
    throw error;
}
/*
 * @description When you invoke this function, Remotion will stop rendering all the frames without any retries.
 * @see [Documentation](https://remotion.dev/docs/cancel-render)
 */
function cancelRender(err) {
    return cancelRenderInternal(typeof window !== 'undefined' ? window : undefined, err);
}
