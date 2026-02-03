"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RemotionRootContexts = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const EditorProps_js_1 = require("./EditorProps.js");
const SequenceManager_js_1 = require("./SequenceManager.js");
const TimelineContext_js_1 = require("./TimelineContext.js");
const shared_audio_tags_js_1 = require("./audio/shared-audio-tags.js");
const buffering_js_1 = require("./buffering.js");
const log_level_context_js_1 = require("./log-level-context.js");
const nonce_js_1 = require("./nonce.js");
const prefetch_state_js_1 = require("./prefetch-state.js");
const use_media_enabled_js_1 = require("./use-media-enabled.js");
const duration_state_js_1 = require("./video/duration-state.js");
const RemotionRootContexts = ({ children, numberOfAudioTags, logLevel, audioLatencyHint, videoEnabled, audioEnabled, frameState, nonceContextSeed, }) => {
    const nonceContext = (0, react_1.useMemo)(() => {
        let counter = 0;
        return {
            getNonce: () => counter++,
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [nonceContextSeed]);
    const logging = (0, react_1.useMemo)(() => {
        return { logLevel, mountTime: Date.now() };
    }, [logLevel]);
    return ((0, jsx_runtime_1.jsx)(log_level_context_js_1.LogLevelContext.Provider, { value: logging, children: (0, jsx_runtime_1.jsx)(nonce_js_1.NonceContext.Provider, { value: nonceContext, children: (0, jsx_runtime_1.jsx)(TimelineContext_js_1.TimelineContextProvider, { frameState: frameState, children: (0, jsx_runtime_1.jsx)(use_media_enabled_js_1.MediaEnabledProvider, { videoEnabled: videoEnabled, audioEnabled: audioEnabled, children: (0, jsx_runtime_1.jsx)(EditorProps_js_1.EditorPropsProvider, { children: (0, jsx_runtime_1.jsx)(prefetch_state_js_1.PrefetchProvider, { children: (0, jsx_runtime_1.jsx)(SequenceManager_js_1.SequenceManagerProvider, { children: (0, jsx_runtime_1.jsx)(shared_audio_tags_js_1.SharedAudioContextProvider, { numberOfAudioTags: numberOfAudioTags, audioLatencyHint: audioLatencyHint, audioEnabled: audioEnabled, children: (0, jsx_runtime_1.jsx)(duration_state_js_1.DurationsContextProvider, { children: (0, jsx_runtime_1.jsx)(buffering_js_1.BufferingProvider, { children: children }) }) }) }) }) }) }) }) }) }));
};
exports.RemotionRootContexts = RemotionRootContexts;
