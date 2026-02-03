"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.useIsPlayerBuffering = exports.BufferingProvider = exports.BufferingContextReact = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = __importStar(require("react"));
const log_level_context_1 = require("./log-level-context");
const playback_logging_1 = require("./playback-logging");
const use_remotion_environment_1 = require("./use-remotion-environment");
const useBufferManager = (logLevel, mountTime) => {
    const [blocks, setBlocks] = (0, react_1.useState)([]);
    const [onBufferingCallbacks, setOnBufferingCallbacks] = (0, react_1.useState)([]);
    const [onResumeCallbacks, setOnResumeCallbacks] = (0, react_1.useState)([]);
    const env = (0, use_remotion_environment_1.useRemotionEnvironment)();
    const rendering = env.isRendering;
    const buffering = (0, react_1.useRef)(false);
    const addBlock = (0, react_1.useCallback)((block) => {
        if (rendering) {
            return {
                unblock: () => undefined,
            };
        }
        setBlocks((b) => [...b, block]);
        return {
            unblock: () => {
                setBlocks((b) => {
                    const newArr = b.filter((bx) => bx !== block);
                    if (newArr.length === b.length) {
                        return b;
                    }
                    return newArr;
                });
            },
        };
    }, [rendering]);
    const listenForBuffering = (0, react_1.useCallback)((callback) => {
        setOnBufferingCallbacks((c) => [...c, callback]);
        return {
            remove: () => {
                setOnBufferingCallbacks((c) => c.filter((cb) => cb !== callback));
            },
        };
    }, []);
    const listenForResume = (0, react_1.useCallback)((callback) => {
        setOnResumeCallbacks((c) => [...c, callback]);
        return {
            remove: () => {
                setOnResumeCallbacks((c) => c.filter((cb) => cb !== callback));
            },
        };
    }, []);
    (0, react_1.useEffect)(() => {
        if (rendering) {
            return;
        }
        if (blocks.length > 0) {
            onBufferingCallbacks.forEach((c) => c());
            (0, playback_logging_1.playbackLogging)({
                logLevel,
                message: 'Player is entering buffer state',
                mountTime,
                tag: 'player',
            });
        }
        // Intentionally only firing when blocks change, not the callbacks
        // otherwise a buffering callback might remove itself after being called
        // and trigger again
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [blocks]);
    if (typeof window !== 'undefined') {
        // eslint-disable-next-line react-hooks/rules-of-hooks
        (0, react_1.useLayoutEffect)(() => {
            if (rendering) {
                return;
            }
            if (blocks.length === 0) {
                onResumeCallbacks.forEach((c) => c());
                (0, playback_logging_1.playbackLogging)({
                    logLevel,
                    message: 'Player is exiting buffer state',
                    mountTime,
                    tag: 'player',
                });
            }
            // Intentionally only firing when blocks change, not the callbacks
            // otherwise a resume callback might remove itself after being called
            // and trigger again
            // eslint-disable-next-line react-hooks/exhaustive-deps
        }, [blocks]);
    }
    return (0, react_1.useMemo)(() => {
        return { addBlock, listenForBuffering, listenForResume, buffering };
    }, [addBlock, buffering, listenForBuffering, listenForResume]);
};
exports.BufferingContextReact = react_1.default.createContext(null);
const BufferingProvider = ({ children }) => {
    const { logLevel, mountTime } = (0, react_1.useContext)(log_level_context_1.LogLevelContext);
    const bufferManager = useBufferManager(logLevel !== null && logLevel !== void 0 ? logLevel : 'info', mountTime);
    return ((0, jsx_runtime_1.jsx)(exports.BufferingContextReact.Provider, { value: bufferManager, children: children }));
};
exports.BufferingProvider = BufferingProvider;
const useIsPlayerBuffering = (bufferManager) => {
    const [isBuffering, setIsBuffering] = (0, react_1.useState)(bufferManager.buffering.current);
    (0, react_1.useEffect)(() => {
        const onBuffer = () => {
            setIsBuffering(true);
        };
        const onResume = () => {
            setIsBuffering(false);
        };
        bufferManager.listenForBuffering(onBuffer);
        bufferManager.listenForResume(onResume);
        return () => {
            bufferManager.listenForBuffering(() => undefined);
            bufferManager.listenForResume(() => undefined);
        };
    }, [bufferManager]);
    return isBuffering;
};
exports.useIsPlayerBuffering = useIsPlayerBuffering;
