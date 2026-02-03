"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.usePlayingState = exports.useTimelineSetFrame = exports.useTimelinePosition = exports.getFrameForComposition = exports.getInitialFrameState = exports.persistCurrentFrame = void 0;
const react_1 = require("react");
const TimelineContext_js_1 = require("./TimelineContext.js");
const use_remotion_environment_js_1 = require("./use-remotion-environment.js");
const use_video_js_1 = require("./use-video.js");
const makeKey = () => {
    return `remotion.time-all`;
};
const persistCurrentFrame = (time) => {
    localStorage.setItem(makeKey(), JSON.stringify(time));
};
exports.persistCurrentFrame = persistCurrentFrame;
const getInitialFrameState = () => {
    var _a;
    const item = (_a = localStorage.getItem(makeKey())) !== null && _a !== void 0 ? _a : '{}';
    const obj = JSON.parse(item);
    return obj;
};
exports.getInitialFrameState = getInitialFrameState;
const getFrameForComposition = (composition) => {
    var _a, _b;
    const item = (_a = localStorage.getItem(makeKey())) !== null && _a !== void 0 ? _a : '{}';
    const obj = JSON.parse(item);
    if (obj[composition] !== undefined) {
        return Number(obj[composition]);
    }
    if (typeof window === 'undefined') {
        return 0;
    }
    return (_b = window.remotion_initialFrame) !== null && _b !== void 0 ? _b : 0;
};
exports.getFrameForComposition = getFrameForComposition;
const useTimelinePosition = () => {
    var _a, _b;
    const videoConfig = (0, use_video_js_1.useVideo)();
    const state = (0, react_1.useContext)(TimelineContext_js_1.TimelineContext);
    const env = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    if (!videoConfig) {
        return typeof window === 'undefined'
            ? 0
            : ((_a = window.remotion_initialFrame) !== null && _a !== void 0 ? _a : 0);
    }
    const unclamped = (_b = state.frame[videoConfig.id]) !== null && _b !== void 0 ? _b : (env.isPlayer ? 0 : (0, exports.getFrameForComposition)(videoConfig.id));
    return Math.min(videoConfig.durationInFrames - 1, unclamped);
};
exports.useTimelinePosition = useTimelinePosition;
const useTimelineSetFrame = () => {
    const { setFrame } = (0, react_1.useContext)(TimelineContext_js_1.SetTimelineContext);
    return setFrame;
};
exports.useTimelineSetFrame = useTimelineSetFrame;
const usePlayingState = () => {
    const { playing, imperativePlaying } = (0, react_1.useContext)(TimelineContext_js_1.TimelineContext);
    const { setPlaying } = (0, react_1.useContext)(TimelineContext_js_1.SetTimelineContext);
    return (0, react_1.useMemo)(() => [playing, setPlaying, imperativePlaying], [imperativePlaying, playing, setPlaying]);
};
exports.usePlayingState = usePlayingState;
