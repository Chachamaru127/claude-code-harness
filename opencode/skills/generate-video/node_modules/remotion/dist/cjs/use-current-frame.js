"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useCurrentFrame = void 0;
const react_1 = require("react");
const CanUseRemotionHooks_js_1 = require("./CanUseRemotionHooks.js");
const SequenceContext_js_1 = require("./SequenceContext.js");
const timeline_position_state_js_1 = require("./timeline-position-state.js");
const use_remotion_environment_js_1 = require("./use-remotion-environment.js");
/*
 * @description Retrieves the current frame of the video within a component. Frames are 0-indexed, and if the component is wrapped in a `<Sequence>`, it returns the frame relative to when the Sequence starts.
 * @see [Documentation](https://www.remotion.dev/docs/use-current-frame)
 */
const useCurrentFrame = () => {
    const canUseRemotionHooks = (0, react_1.useContext)(CanUseRemotionHooks_js_1.CanUseRemotionHooks);
    const env = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    if (!canUseRemotionHooks) {
        if (env.isPlayer) {
            throw new Error(`useCurrentFrame can only be called inside a component that was passed to <Player>. See: https://www.remotion.dev/docs/player/examples`);
        }
        throw new Error(`useCurrentFrame() can only be called inside a component that was registered as a composition. See https://www.remotion.dev/docs/the-fundamentals#defining-compositions`);
    }
    const frame = (0, timeline_position_state_js_1.useTimelinePosition)();
    const context = (0, react_1.useContext)(SequenceContext_js_1.SequenceContext);
    const contextOffset = context
        ? context.cumulatedFrom + context.relativeFrom
        : 0;
    return frame - contextOffset;
};
exports.useCurrentFrame = useCurrentFrame;
