"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.IFrame = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const use_delay_render_js_1 = require("./use-delay-render.js");
const IFrameRefForwarding = ({ onLoad, onError, delayRenderRetries, delayRenderTimeoutInMilliseconds, ...props }, ref) => {
    const { delayRender, continueRender } = (0, use_delay_render_js_1.useDelayRender)();
    const [handle] = (0, react_1.useState)(() => delayRender(`Loading <IFrame> with source ${props.src}`, {
        retries: delayRenderRetries !== null && delayRenderRetries !== void 0 ? delayRenderRetries : undefined,
        timeoutInMilliseconds: delayRenderTimeoutInMilliseconds !== null && delayRenderTimeoutInMilliseconds !== void 0 ? delayRenderTimeoutInMilliseconds : undefined,
    }));
    const didLoad = (0, react_1.useCallback)((e) => {
        continueRender(handle);
        onLoad === null || onLoad === void 0 ? void 0 : onLoad(e);
    }, [handle, onLoad, continueRender]);
    const didGetError = (0, react_1.useCallback)((e) => {
        continueRender(handle);
        if (onError) {
            onError(e);
        }
        else {
            // eslint-disable-next-line no-console
            console.error('Error loading iframe:', e, 'Handle the event using the onError() prop to make this message disappear.');
        }
    }, [handle, onError, continueRender]);
    return ((0, jsx_runtime_1.jsx)("iframe", { referrerPolicy: "strict-origin-when-cross-origin", ...props, ref: ref, onError: didGetError, onLoad: didLoad }));
};
/*
 * @description The <IFrame /> can be used like a regular <iframe> HTML tag.
 * @see [Documentation](https://remotion.dev/docs/iframe)
 */
exports.IFrame = (0, react_1.forwardRef)(IFrameRefForwarding);
