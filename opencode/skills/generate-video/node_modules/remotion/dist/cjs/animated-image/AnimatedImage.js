"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AnimatedImage = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const cancel_render_js_1 = require("../cancel-render.js");
const use_current_frame_js_1 = require("../use-current-frame.js");
const use_delay_render_js_1 = require("../use-delay-render.js");
const use_video_config_js_1 = require("../use-video-config.js");
const canvas_1 = require("./canvas");
const decode_image_js_1 = require("./decode-image.js");
const resolve_image_source_1 = require("./resolve-image-source");
exports.AnimatedImage = (0, react_1.forwardRef)(({ src, width, height, onError, loopBehavior = 'loop', playbackRate = 1, fit = 'fill', ...props }, canvasRef) => {
    const mountState = (0, react_1.useRef)({ isMounted: true });
    (0, react_1.useEffect)(() => {
        const { current } = mountState;
        current.isMounted = true;
        return () => {
            current.isMounted = false;
        };
    }, []);
    const resolvedSrc = (0, resolve_image_source_1.resolveAnimatedImageSource)(src);
    const [imageDecoder, setImageDecoder] = (0, react_1.useState)(null);
    const { delayRender, continueRender } = (0, use_delay_render_js_1.useDelayRender)();
    const [decodeHandle] = (0, react_1.useState)(() => delayRender(`Rendering <AnimatedImage/> with src="${resolvedSrc}"`));
    const frame = (0, use_current_frame_js_1.useCurrentFrame)();
    const { fps } = (0, use_video_config_js_1.useVideoConfig)();
    const currentTime = frame / playbackRate / fps;
    const currentTimeRef = (0, react_1.useRef)(currentTime);
    currentTimeRef.current = currentTime;
    const ref = (0, react_1.useRef)(null);
    (0, react_1.useImperativeHandle)(canvasRef, () => {
        var _a;
        const c = (_a = ref.current) === null || _a === void 0 ? void 0 : _a.getCanvas();
        if (!c) {
            throw new Error('Canvas ref is not set');
        }
        return c;
    }, []);
    const [initialLoopBehavior] = (0, react_1.useState)(() => loopBehavior);
    (0, react_1.useEffect)(() => {
        const controller = new AbortController();
        (0, decode_image_js_1.decodeImage)({
            resolvedSrc,
            signal: controller.signal,
            currentTime: currentTimeRef.current,
            initialLoopBehavior,
        })
            .then((d) => {
            setImageDecoder(d);
            continueRender(decodeHandle);
        })
            .catch((err) => {
            if (err.name === 'AbortError') {
                continueRender(decodeHandle);
                return;
            }
            if (onError) {
                onError === null || onError === void 0 ? void 0 : onError(err);
                continueRender(decodeHandle);
            }
            else {
                (0, cancel_render_js_1.cancelRender)(err);
            }
        });
        return () => {
            controller.abort();
        };
    }, [
        resolvedSrc,
        decodeHandle,
        onError,
        initialLoopBehavior,
        continueRender,
    ]);
    (0, react_1.useLayoutEffect)(() => {
        if (!imageDecoder) {
            return;
        }
        const delay = delayRender(`Rendering frame at ${currentTime} of <AnimatedImage src="${src}"/>`);
        imageDecoder
            .getFrame(currentTime, loopBehavior)
            .then((videoFrame) => {
            var _a, _b;
            if (mountState.current.isMounted) {
                if (videoFrame === null) {
                    (_a = ref.current) === null || _a === void 0 ? void 0 : _a.clear();
                }
                else {
                    (_b = ref.current) === null || _b === void 0 ? void 0 : _b.draw(videoFrame.frame);
                }
            }
            continueRender(delay);
        })
            .catch((err) => {
            if (onError) {
                onError(err);
                continueRender(delay);
            }
            else {
                (0, cancel_render_js_1.cancelRender)(err);
            }
        });
    }, [
        currentTime,
        imageDecoder,
        loopBehavior,
        onError,
        src,
        continueRender,
        delayRender,
    ]);
    return ((0, jsx_runtime_1.jsx)(canvas_1.Canvas, { ref: ref, width: width, height: height, fit: fit, ...props }));
});
