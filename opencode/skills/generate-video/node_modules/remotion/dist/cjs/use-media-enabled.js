"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MediaEnabledProvider = exports.useAudioEnabled = exports.useVideoEnabled = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const MediaEnabledContext = (0, react_1.createContext)(null);
const useVideoEnabled = () => {
    const context = (0, react_1.useContext)(MediaEnabledContext);
    if (!context) {
        return window.remotion_videoEnabled;
    }
    if (context.videoEnabled === null) {
        return window.remotion_videoEnabled;
    }
    return context.videoEnabled;
};
exports.useVideoEnabled = useVideoEnabled;
const useAudioEnabled = () => {
    const context = (0, react_1.useContext)(MediaEnabledContext);
    if (!context) {
        return window.remotion_audioEnabled;
    }
    if (context.audioEnabled === null) {
        return window.remotion_audioEnabled;
    }
    return context.audioEnabled;
};
exports.useAudioEnabled = useAudioEnabled;
const MediaEnabledProvider = ({ children, videoEnabled, audioEnabled, }) => {
    const value = (0, react_1.useMemo)(() => ({ videoEnabled, audioEnabled }), [videoEnabled, audioEnabled]);
    return ((0, jsx_runtime_1.jsx)(MediaEnabledContext.Provider, { value: value, children: children }));
};
exports.MediaEnabledProvider = MediaEnabledProvider;
