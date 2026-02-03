"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TimelineContextProvider = exports.TimelineContext = exports.SetTimelineContext = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const random_1 = require("./random");
const timeline_position_state_1 = require("./timeline-position-state");
const use_delay_render_1 = require("./use-delay-render");
exports.SetTimelineContext = (0, react_1.createContext)({
    setFrame: () => {
        throw new Error('default');
    },
    setPlaying: () => {
        throw new Error('default');
    },
});
exports.TimelineContext = (0, react_1.createContext)({
    frame: {},
    playing: false,
    playbackRate: 1,
    rootId: '',
    imperativePlaying: {
        current: false,
    },
    setPlaybackRate: () => {
        throw new Error('default');
    },
    audioAndVideoTags: { current: [] },
});
const TimelineContextProvider = ({ children, frameState }) => {
    const [playing, setPlaying] = (0, react_1.useState)(false);
    const imperativePlaying = (0, react_1.useRef)(false);
    const [playbackRate, setPlaybackRate] = (0, react_1.useState)(1);
    const audioAndVideoTags = (0, react_1.useRef)([]);
    const [remotionRootId] = (0, react_1.useState)(() => String((0, random_1.random)(null)));
    const [_frame, setFrame] = (0, react_1.useState)(() => (0, timeline_position_state_1.getInitialFrameState)());
    const frame = frameState !== null && frameState !== void 0 ? frameState : _frame;
    const { delayRender, continueRender } = (0, use_delay_render_1.useDelayRender)();
    if (typeof window !== 'undefined') {
        // eslint-disable-next-line react-hooks/rules-of-hooks
        (0, react_1.useLayoutEffect)(() => {
            window.remotion_setFrame = (f, composition, attempt) => {
                window.remotion_attempt = attempt;
                const id = delayRender(`Setting the current frame to ${f}`);
                let asyncUpdate = true;
                setFrame((s) => {
                    var _a;
                    const currentFrame = (_a = s[composition]) !== null && _a !== void 0 ? _a : window.remotion_initialFrame;
                    // Avoid cloning the object
                    if (currentFrame === f) {
                        asyncUpdate = false;
                        return s;
                    }
                    return {
                        ...s,
                        [composition]: f,
                    };
                });
                // After setting the state, need to wait until it is applied in the next cycle
                if (asyncUpdate) {
                    requestAnimationFrame(() => continueRender(id));
                }
                else {
                    continueRender(id);
                }
            };
            window.remotion_isPlayer = false;
        }, [continueRender, delayRender]);
    }
    const timelineContextValue = (0, react_1.useMemo)(() => {
        return {
            frame,
            playing,
            imperativePlaying,
            rootId: remotionRootId,
            playbackRate,
            setPlaybackRate,
            audioAndVideoTags,
        };
    }, [frame, playbackRate, playing, remotionRootId]);
    const setTimelineContextValue = (0, react_1.useMemo)(() => {
        return {
            setFrame,
            setPlaying,
        };
    }, []);
    return ((0, jsx_runtime_1.jsx)(exports.TimelineContext.Provider, { value: timelineContextValue, children: (0, jsx_runtime_1.jsx)(exports.SetTimelineContext.Provider, { value: setTimelineContextValue, children: children }) }));
};
exports.TimelineContextProvider = TimelineContextProvider;
