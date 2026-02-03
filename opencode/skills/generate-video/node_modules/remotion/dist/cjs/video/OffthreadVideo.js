"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OffthreadVideo = exports.InnerOffthreadVideo = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const Sequence_js_1 = require("../Sequence.js");
const enable_sequence_stack_traces_js_1 = require("../enable-sequence-stack-traces.js");
const use_remotion_environment_js_1 = require("../use-remotion-environment.js");
const validate_media_props_js_1 = require("../validate-media-props.js");
const validate_start_from_props_js_1 = require("../validate-start-from-props.js");
const OffthreadVideoForRendering_js_1 = require("./OffthreadVideoForRendering.js");
const VideoForPreview_js_1 = require("./VideoForPreview.js");
const InnerOffthreadVideo = (props) => {
    // Should only destruct `startFrom` and `endAt` from props,
    // rest gets drilled down
    const { startFrom, endAt, trimBefore, trimAfter, name, pauseWhenBuffering, stack, showInTimeline, ...otherProps } = props;
    const environment = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    if (environment.isClientSideRendering) {
        throw new Error('<OffthreadVideo> is not supported in @remotion/web-renderer. Use <Video> from @remotion/media instead. See https://remotion.dev/docs/client-side-rendering/limitations');
    }
    const onDuration = (0, react_1.useCallback)(() => undefined, []);
    if (typeof props.src !== 'string') {
        throw new TypeError(`The \`<OffthreadVideo>\` tag requires a string for \`src\`, but got ${JSON.stringify(props.src)} instead.`);
    }
    (0, validate_start_from_props_js_1.validateMediaTrimProps)({ startFrom, endAt, trimBefore, trimAfter });
    const { trimBeforeValue, trimAfterValue } = (0, validate_start_from_props_js_1.resolveTrimProps)({
        startFrom,
        endAt,
        trimBefore,
        trimAfter,
    });
    if (typeof trimBeforeValue !== 'undefined' ||
        typeof trimAfterValue !== 'undefined') {
        return ((0, jsx_runtime_1.jsx)(Sequence_js_1.Sequence, { layout: "none", from: 0 - (trimBeforeValue !== null && trimBeforeValue !== void 0 ? trimBeforeValue : 0), showInTimeline: false, durationInFrames: trimAfterValue, name: name, children: (0, jsx_runtime_1.jsx)(exports.InnerOffthreadVideo, { pauseWhenBuffering: pauseWhenBuffering !== null && pauseWhenBuffering !== void 0 ? pauseWhenBuffering : false, ...otherProps, trimAfter: undefined, name: undefined, showInTimeline: showInTimeline, trimBefore: undefined, stack: undefined, startFrom: undefined, endAt: undefined }) }));
    }
    (0, validate_media_props_js_1.validateMediaProps)(props, 'Video');
    if (environment.isRendering) {
        return ((0, jsx_runtime_1.jsx)(OffthreadVideoForRendering_js_1.OffthreadVideoForRendering, { pauseWhenBuffering: pauseWhenBuffering !== null && pauseWhenBuffering !== void 0 ? pauseWhenBuffering : false, ...otherProps, trimAfter: undefined, name: undefined, showInTimeline: showInTimeline, trimBefore: undefined, stack: undefined, startFrom: undefined, endAt: undefined }));
    }
    const { transparent, toneMapped, onAutoPlayError, onVideoFrame, crossOrigin, delayRenderRetries, delayRenderTimeoutInMilliseconds, ...propsForPreview } = otherProps;
    return ((0, jsx_runtime_1.jsx)(VideoForPreview_js_1.VideoForPreview, { _remotionInternalStack: stack !== null && stack !== void 0 ? stack : null, onDuration: onDuration, onlyWarnForMediaSeekingError: true, pauseWhenBuffering: pauseWhenBuffering !== null && pauseWhenBuffering !== void 0 ? pauseWhenBuffering : false, showInTimeline: showInTimeline !== null && showInTimeline !== void 0 ? showInTimeline : true, onAutoPlayError: onAutoPlayError !== null && onAutoPlayError !== void 0 ? onAutoPlayError : undefined, onVideoFrame: onVideoFrame !== null && onVideoFrame !== void 0 ? onVideoFrame : null, crossOrigin: crossOrigin, ...propsForPreview, _remotionInternalNativeLoopPassed: false }));
};
exports.InnerOffthreadVideo = InnerOffthreadVideo;
/*
 * @description This method imports and displays a video, similar to <Html5Video />. During rendering, it extracts the exact frame from the video and displays it in an <img> tag
 * @see [Documentation](https://www.remotion.dev/docs/offthreadvideo)
 */
const OffthreadVideo = ({ src, acceptableTimeShiftInSeconds, allowAmplificationDuringRender, audioStreamIndex, className, crossOrigin, delayRenderRetries, delayRenderTimeoutInMilliseconds, id, loopVolumeCurveBehavior, muted, name, onAutoPlayError, onError, onVideoFrame, pauseWhenBuffering, playbackRate, showInTimeline, style, toneFrequency, toneMapped, transparent, trimAfter, trimBefore, useWebAudioApi, volume, _remotionInternalNativeLoopPassed, endAt, stack, startFrom, imageFormat, }) => {
    if (imageFormat) {
        throw new TypeError(`The \`<OffthreadVideo>\` tag does no longer accept \`imageFormat\`. Use the \`transparent\` prop if you want to render a transparent video.`);
    }
    return ((0, jsx_runtime_1.jsx)(exports.InnerOffthreadVideo, { acceptableTimeShiftInSeconds: acceptableTimeShiftInSeconds, allowAmplificationDuringRender: allowAmplificationDuringRender !== null && allowAmplificationDuringRender !== void 0 ? allowAmplificationDuringRender : true, audioStreamIndex: audioStreamIndex !== null && audioStreamIndex !== void 0 ? audioStreamIndex : 0, className: className, crossOrigin: crossOrigin, delayRenderRetries: delayRenderRetries, delayRenderTimeoutInMilliseconds: delayRenderTimeoutInMilliseconds, id: id, loopVolumeCurveBehavior: loopVolumeCurveBehavior !== null && loopVolumeCurveBehavior !== void 0 ? loopVolumeCurveBehavior : 'repeat', muted: muted !== null && muted !== void 0 ? muted : false, name: name, onAutoPlayError: onAutoPlayError !== null && onAutoPlayError !== void 0 ? onAutoPlayError : null, onError: onError, onVideoFrame: onVideoFrame, pauseWhenBuffering: pauseWhenBuffering !== null && pauseWhenBuffering !== void 0 ? pauseWhenBuffering : true, playbackRate: playbackRate !== null && playbackRate !== void 0 ? playbackRate : 1, toneFrequency: toneFrequency !== null && toneFrequency !== void 0 ? toneFrequency : 1, showInTimeline: showInTimeline !== null && showInTimeline !== void 0 ? showInTimeline : true, src: src, stack: stack, startFrom: startFrom, _remotionInternalNativeLoopPassed: _remotionInternalNativeLoopPassed !== null && _remotionInternalNativeLoopPassed !== void 0 ? _remotionInternalNativeLoopPassed : false, endAt: endAt, style: style, toneMapped: toneMapped !== null && toneMapped !== void 0 ? toneMapped : true, transparent: transparent !== null && transparent !== void 0 ? transparent : false, trimAfter: trimAfter, trimBefore: trimBefore, useWebAudioApi: useWebAudioApi !== null && useWebAudioApi !== void 0 ? useWebAudioApi : false, volume: volume }));
};
exports.OffthreadVideo = OffthreadVideo;
(0, enable_sequence_stack_traces_js_1.addSequenceStackTraces)(exports.OffthreadVideo);
