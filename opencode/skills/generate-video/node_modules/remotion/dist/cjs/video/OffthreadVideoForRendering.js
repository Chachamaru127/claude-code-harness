"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OffthreadVideoForRendering = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const Img_js_1 = require("../Img.js");
const RenderAssetManager_js_1 = require("../RenderAssetManager.js");
const SequenceContext_js_1 = require("../SequenceContext.js");
const absolute_src_js_1 = require("../absolute-src.js");
const use_audio_frame_js_1 = require("../audio/use-audio-frame.js");
const cancel_render_js_1 = require("../cancel-render.js");
const default_css_js_1 = require("../default-css.js");
const random_js_1 = require("../random.js");
const timeline_position_state_js_1 = require("../timeline-position-state.js");
const truthy_js_1 = require("../truthy.js");
const use_current_frame_js_1 = require("../use-current-frame.js");
const use_delay_render_js_1 = require("../use-delay-render.js");
const use_unsafe_video_config_js_1 = require("../use-unsafe-video-config.js");
const volume_prop_js_1 = require("../volume-prop.js");
const volume_safeguard_js_1 = require("../volume-safeguard.js");
const get_current_time_js_1 = require("./get-current-time.js");
const offthread_video_source_js_1 = require("./offthread-video-source.js");
const OffthreadVideoForRendering = ({ onError, volume: volumeProp, playbackRate, src, muted, allowAmplificationDuringRender, transparent, toneMapped, toneFrequency, name, loopVolumeCurveBehavior, delayRenderRetries, delayRenderTimeoutInMilliseconds, onVideoFrame, 
// Remove crossOrigin prop during rendering
// https://discord.com/channels/809501355504959528/844143007183667220/1311639632496033813
crossOrigin, audioStreamIndex, ...props }) => {
    const absoluteFrame = (0, timeline_position_state_js_1.useTimelinePosition)();
    const frame = (0, use_current_frame_js_1.useCurrentFrame)();
    const volumePropsFrame = (0, use_audio_frame_js_1.useFrameForVolumeProp)(loopVolumeCurveBehavior);
    const videoConfig = (0, use_unsafe_video_config_js_1.useUnsafeVideoConfig)();
    const sequenceContext = (0, react_1.useContext)(SequenceContext_js_1.SequenceContext);
    const mediaStartsAt = (0, use_audio_frame_js_1.useMediaStartsAt)();
    const { registerRenderAsset, unregisterRenderAsset } = (0, react_1.useContext)(RenderAssetManager_js_1.RenderAssetManager);
    if (!src) {
        throw new TypeError('No `src` was passed to <OffthreadVideo>.');
    }
    // Generate a string that's as unique as possible for this asset
    // but at the same time the same on all threads
    const id = (0, react_1.useMemo)(() => `offthreadvideo-${(0, random_js_1.random)(src)}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.cumulatedFrom}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom}-${sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.durationInFrames}`, [
        src,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.cumulatedFrom,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.durationInFrames,
    ]);
    if (!videoConfig) {
        throw new Error('No video config found');
    }
    const volume = (0, volume_prop_js_1.evaluateVolume)({
        volume: volumeProp,
        frame: volumePropsFrame,
        mediaVolume: 1,
    });
    (0, volume_safeguard_js_1.warnAboutTooHighVolume)(volume);
    (0, react_1.useEffect)(() => {
        var _a;
        if (!src) {
            throw new Error('No src passed');
        }
        if (!window.remotion_audioEnabled) {
            return;
        }
        if (muted) {
            return;
        }
        if (volume <= 0) {
            return;
        }
        registerRenderAsset({
            type: 'video',
            src: (0, absolute_src_js_1.getAbsoluteSrc)(src),
            id,
            frame: absoluteFrame,
            volume,
            mediaFrame: frame,
            playbackRate,
            toneFrequency,
            audioStartFrame: Math.max(0, -((_a = sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom) !== null && _a !== void 0 ? _a : 0)),
            audioStreamIndex,
        });
        return () => unregisterRenderAsset(id);
    }, [
        muted,
        src,
        registerRenderAsset,
        id,
        unregisterRenderAsset,
        volume,
        frame,
        absoluteFrame,
        playbackRate,
        toneFrequency,
        sequenceContext === null || sequenceContext === void 0 ? void 0 : sequenceContext.relativeFrom,
        audioStreamIndex,
    ]);
    const currentTime = (0, react_1.useMemo)(() => {
        return ((0, get_current_time_js_1.getExpectedMediaFrameUncorrected)({
            frame,
            playbackRate: playbackRate || 1,
            startFrom: -mediaStartsAt,
        }) / videoConfig.fps);
    }, [frame, mediaStartsAt, playbackRate, videoConfig.fps]);
    const actualSrc = (0, react_1.useMemo)(() => {
        return (0, offthread_video_source_js_1.getOffthreadVideoSource)({
            src,
            currentTime,
            transparent,
            toneMapped,
        });
    }, [toneMapped, currentTime, src, transparent]);
    const [imageSrc, setImageSrc] = (0, react_1.useState)(null);
    const { delayRender, continueRender } = (0, use_delay_render_js_1.useDelayRender)();
    (0, react_1.useLayoutEffect)(() => {
        if (!window.remotion_videoEnabled) {
            return;
        }
        const cleanup = [];
        setImageSrc(null);
        const controller = new AbortController();
        const newHandle = delayRender(`Fetching ${actualSrc} from server`, {
            retries: delayRenderRetries !== null && delayRenderRetries !== void 0 ? delayRenderRetries : undefined,
            timeoutInMilliseconds: delayRenderTimeoutInMilliseconds !== null && delayRenderTimeoutInMilliseconds !== void 0 ? delayRenderTimeoutInMilliseconds : undefined,
        });
        const execute = async () => {
            try {
                const res = await fetch(actualSrc, {
                    signal: controller.signal,
                    cache: 'no-store',
                });
                if (res.status !== 200) {
                    if (res.status === 500) {
                        const json = await res.json();
                        if (json.error) {
                            const cleanedUpErrorMessage = json.error.replace(/^Error: /, '');
                            throw new Error(cleanedUpErrorMessage);
                        }
                    }
                    throw new Error(`Server returned status ${res.status} while fetching ${actualSrc}`);
                }
                const blob = await res.blob();
                const url = URL.createObjectURL(blob);
                cleanup.push(() => URL.revokeObjectURL(url));
                setImageSrc({
                    src: url,
                    handle: newHandle,
                });
            }
            catch (err) {
                // If component is unmounted, we should not throw
                if (err.message.includes('aborted')) {
                    continueRender(newHandle);
                    return;
                }
                if (controller.signal.aborted) {
                    continueRender(newHandle);
                    return;
                }
                if (err.message.includes('Failed to fetch')) {
                    // eslint-disable-next-line no-ex-assign
                    err = new Error(`Failed to fetch ${actualSrc}. This could be caused by Chrome rejecting the request because the disk space is low. Consider increasing the disk size of your environment.`, { cause: err });
                }
                if (onError) {
                    onError(err);
                }
                else {
                    (0, cancel_render_js_1.cancelRender)(err);
                }
            }
        };
        execute();
        cleanup.push(() => {
            if (controller.signal.aborted) {
                return;
            }
            controller.abort();
        });
        return () => {
            cleanup.forEach((c) => c());
        };
    }, [
        actualSrc,
        delayRenderRetries,
        delayRenderTimeoutInMilliseconds,
        onError,
        continueRender,
        delayRender,
    ]);
    const onErr = (0, react_1.useCallback)(() => {
        if (onError) {
            onError === null || onError === void 0 ? void 0 : onError(new Error('Failed to load image with src ' + imageSrc));
        }
        else {
            (0, cancel_render_js_1.cancelRender)('Failed to load image with src ' + imageSrc);
        }
    }, [imageSrc, onError]);
    const className = (0, react_1.useMemo)(() => {
        return [default_css_js_1.OBJECTFIT_CONTAIN_CLASS_NAME, props.className]
            .filter(truthy_js_1.truthy)
            .join(' ');
    }, [props.className]);
    const onImageFrame = (0, react_1.useCallback)((img) => {
        if (onVideoFrame) {
            onVideoFrame(img);
        }
    }, [onVideoFrame]);
    if (!imageSrc || !window.remotion_videoEnabled) {
        return null;
    }
    continueRender(imageSrc.handle);
    return ((0, jsx_runtime_1.jsx)(Img_js_1.Img, { src: imageSrc.src, delayRenderRetries: delayRenderRetries, delayRenderTimeoutInMilliseconds: delayRenderTimeoutInMilliseconds, onImageFrame: onImageFrame, ...props, onError: onErr, className: className }));
};
exports.OffthreadVideoForRendering = OffthreadVideoForRendering;
