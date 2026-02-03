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
exports.useSharedAudio = exports.SharedAudioContextProvider = exports.SharedAudioContext = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = __importStar(require("react"));
const log_level_context_js_1 = require("../log-level-context.js");
const play_and_handle_not_allowed_error_js_1 = require("../play-and-handle-not-allowed-error.js");
const use_remotion_environment_js_1 = require("../use-remotion-environment.js");
const shared_element_source_node_js_1 = require("./shared-element-source-node.js");
const use_audio_context_js_1 = require("./use-audio-context.js");
const EMPTY_AUDIO = 'data:audio/mp3;base64,/+MYxAAJcAV8AAgAABn//////+/gQ5BAMA+D4Pg+BAQBAEAwD4Pg+D4EBAEAQDAPg++hYBH///hUFQVBUFREDQNHmf///////+MYxBUGkAGIMAAAAP/29Xt6lUxBTUUzLjEwMFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV/+MYxDUAAANIAAAAAFVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV';
const compareProps = (obj1, obj2) => {
    const keysA = Object.keys(obj1).sort();
    const keysB = Object.keys(obj2).sort();
    if (keysA.length !== keysB.length) {
        return false;
    }
    for (let i = 0; i < keysA.length; i++) {
        // Not the same keys
        if (keysA[i] !== keysB[i]) {
            return false;
        }
        // Not the same values
        if (obj1[keysA[i]] !== obj2[keysB[i]]) {
            return false;
        }
    }
    return true;
};
const didPropChange = (key, newProp, prevProp) => {
    // /music.mp3 and http://localhost:3000/music.mp3 are the same
    if (key === 'src' &&
        !prevProp.startsWith('data:') &&
        !newProp.startsWith('data:')) {
        return (new URL(prevProp, window.origin).toString() !==
            new URL(newProp, window.origin).toString());
    }
    if (prevProp === newProp) {
        return false;
    }
    return true;
};
exports.SharedAudioContext = (0, react_1.createContext)(null);
const SharedAudioContextProvider = ({ children, numberOfAudioTags, audioLatencyHint, audioEnabled }) => {
    var _a;
    const audios = (0, react_1.useRef)([]);
    const [initialNumberOfAudioTags] = (0, react_1.useState)(numberOfAudioTags);
    if (numberOfAudioTags !== initialNumberOfAudioTags) {
        throw new Error('The number of shared audio tags has changed dynamically. Once you have set this property, you cannot change it afterwards.');
    }
    const logLevel = (0, log_level_context_js_1.useLogLevel)();
    const audioContext = (0, use_audio_context_js_1.useSingletonAudioContext)({
        logLevel,
        latencyHint: audioLatencyHint,
        audioEnabled,
    });
    const refs = (0, react_1.useMemo)(() => {
        return new Array(numberOfAudioTags).fill(true).map(() => {
            const ref = (0, react_1.createRef)();
            return {
                id: Math.random(),
                ref,
                mediaElementSourceNode: audioContext
                    ? (0, shared_element_source_node_js_1.makeSharedElementSourceNode)({
                        audioContext,
                        ref,
                    })
                    : null,
            };
        });
    }, [audioContext, numberOfAudioTags]);
    /**
     * Effects in React 18 fire twice, and we are looking for a way to only fire it once.
     * - useInsertionEffect only fires once. If it's available we are in React 18.
     * - useLayoutEffect only fires once in React 17.
     *
     * Need to import it from React to fix React 17 ESM support.
     */
    const effectToUse = (_a = react_1.default.useInsertionEffect) !== null && _a !== void 0 ? _a : react_1.default.useLayoutEffect;
    // Disconnecting the SharedElementSourceNodes if the Player unmounts to prevent leak.
    // https://github.com/remotion-dev/remotion/issues/6285
    // But useInsertionEffect will fire before other effects, meaning the
    // nodes might still be used. Using rAF to ensure it's after other effects.
    effectToUse(() => {
        return () => {
            requestAnimationFrame(() => {
                refs.forEach(({ mediaElementSourceNode }) => {
                    mediaElementSourceNode === null || mediaElementSourceNode === void 0 ? void 0 : mediaElementSourceNode.cleanup();
                });
            });
        };
    }, [refs]);
    const takenAudios = (0, react_1.useRef)(new Array(numberOfAudioTags).fill(false));
    const rerenderAudios = (0, react_1.useCallback)(() => {
        refs.forEach(({ ref, id }) => {
            var _a;
            const data = (_a = audios.current) === null || _a === void 0 ? void 0 : _a.find((a) => a.id === id);
            const { current } = ref;
            if (!current) {
                // Whole player has been unmounted, the refs don't exist anymore.
                // It is not an error anymore though
                return;
            }
            if (data === undefined) {
                current.src = EMPTY_AUDIO;
                return;
            }
            if (!data) {
                throw new TypeError('Expected audio data to be there');
            }
            Object.keys(data.props).forEach((key) => {
                // @ts-expect-error
                if (didPropChange(key, data.props[key], current[key])) {
                    // @ts-expect-error
                    current[key] = data.props[key];
                }
            });
        });
    }, [refs]);
    const registerAudio = (0, react_1.useCallback)((options) => {
        var _a, _b;
        const { aud, audioId, premounting, postmounting } = options;
        const found = (_a = audios.current) === null || _a === void 0 ? void 0 : _a.find((a) => a.audioId === audioId);
        if (found) {
            return found;
        }
        const firstFreeAudio = takenAudios.current.findIndex((a) => a === false);
        if (firstFreeAudio === -1) {
            throw new Error(`Tried to simultaneously mount ${numberOfAudioTags + 1} <Html5Audio /> tags at the same time. With the current settings, the maximum amount of <Html5Audio /> tags is limited to ${numberOfAudioTags} at the same time. Remotion pre-mounts silent audio tags to help avoid browser autoplay restrictions. See https://remotion.dev/docs/player/autoplay#using-the-numberofsharedaudiotags-prop for more information on how to increase this limit.`);
        }
        const { id, ref, mediaElementSourceNode } = refs[firstFreeAudio];
        const cloned = [...takenAudios.current];
        cloned[firstFreeAudio] = id;
        takenAudios.current = cloned;
        const newElem = {
            props: aud,
            id,
            el: ref,
            audioId,
            mediaElementSourceNode,
            premounting,
            audioMounted: Boolean(ref.current),
            postmounting,
            cleanupOnMediaTagUnmount: () => {
                // Don't disconnect here, only when the Player unmounts.
            },
        };
        (_b = audios.current) === null || _b === void 0 ? void 0 : _b.push(newElem);
        rerenderAudios();
        return newElem;
    }, [numberOfAudioTags, refs, rerenderAudios]);
    const unregisterAudio = (0, react_1.useCallback)((id) => {
        var _a;
        const cloned = [...takenAudios.current];
        const index = refs.findIndex((r) => r.id === id);
        if (index === -1) {
            throw new TypeError('Error occured in ');
        }
        cloned[index] = false;
        takenAudios.current = cloned;
        audios.current = (_a = audios.current) === null || _a === void 0 ? void 0 : _a.filter((a) => a.id !== id);
        rerenderAudios();
    }, [refs, rerenderAudios]);
    const updateAudio = (0, react_1.useCallback)(({ aud, audioId, id, premounting, postmounting, }) => {
        var _a;
        let changed = false;
        audios.current = (_a = audios.current) === null || _a === void 0 ? void 0 : _a.map((prevA) => {
            const audioMounted = Boolean(prevA.el.current);
            if (prevA.audioMounted !== audioMounted) {
                changed = true;
            }
            if (prevA.id === id) {
                const isTheSame = compareProps(aud, prevA.props) &&
                    prevA.premounting === premounting &&
                    prevA.postmounting === postmounting;
                if (isTheSame) {
                    return prevA;
                }
                changed = true;
                return {
                    ...prevA,
                    props: aud,
                    premounting,
                    postmounting,
                    audioId,
                    audioMounted,
                };
            }
            return prevA;
        });
        if (changed) {
            rerenderAudios();
        }
    }, [rerenderAudios]);
    const mountTime = (0, log_level_context_js_1.useMountTime)();
    const env = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    const playAllAudios = (0, react_1.useCallback)(() => {
        refs.forEach((ref) => {
            const audio = audios.current.find((a) => a.el === ref.ref);
            if (audio === null || audio === void 0 ? void 0 : audio.premounting) {
                return;
            }
            (0, play_and_handle_not_allowed_error_js_1.playAndHandleNotAllowedError)({
                mediaRef: ref.ref,
                mediaType: 'audio',
                onAutoPlayError: null,
                logLevel,
                mountTime,
                reason: 'playing all audios',
                isPlayer: env.isPlayer,
            });
        });
        audioContext === null || audioContext === void 0 ? void 0 : audioContext.resume();
    }, [audioContext, logLevel, mountTime, refs, env.isPlayer]);
    const value = (0, react_1.useMemo)(() => {
        return {
            registerAudio,
            unregisterAudio,
            updateAudio,
            playAllAudios,
            numberOfAudioTags,
            audioContext,
        };
    }, [
        numberOfAudioTags,
        playAllAudios,
        registerAudio,
        unregisterAudio,
        updateAudio,
        audioContext,
    ]);
    return ((0, jsx_runtime_1.jsxs)(exports.SharedAudioContext.Provider, { value: value, children: [refs.map(({ id, ref }) => {
                return (
                // Without preload="metadata", iOS will seek the time internally
                // but not actually with sound. Adding `preload="metadata"` helps here.
                // https://discord.com/channels/809501355504959528/817306414069710848/1130519583367888906
                (0, jsx_runtime_1.jsx)("audio", { ref: ref, preload: "metadata", src: EMPTY_AUDIO }, id));
            }), children] }));
};
exports.SharedAudioContextProvider = SharedAudioContextProvider;
const useSharedAudio = ({ aud, audioId, premounting, postmounting, }) => {
    var _a;
    const ctx = (0, react_1.useContext)(exports.SharedAudioContext);
    /**
     * We work around this in React 18 so an audio tag will only register itself once
     */
    const [elem] = (0, react_1.useState)(() => {
        if (ctx && ctx.numberOfAudioTags > 0) {
            return ctx.registerAudio({ aud, audioId, premounting, postmounting });
        }
        // numberOfSharedAudioTags is 0
        const el = react_1.default.createRef();
        const mediaElementSourceNode = (ctx === null || ctx === void 0 ? void 0 : ctx.audioContext)
            ? (0, shared_element_source_node_js_1.makeSharedElementSourceNode)({
                audioContext: ctx.audioContext,
                ref: el,
            })
            : null;
        return {
            el,
            id: Math.random(),
            props: aud,
            audioId,
            mediaElementSourceNode,
            premounting,
            audioMounted: Boolean(el.current),
            postmounting,
            cleanupOnMediaTagUnmount: () => {
                mediaElementSourceNode === null || mediaElementSourceNode === void 0 ? void 0 : mediaElementSourceNode.cleanup();
            },
        };
    });
    /**
     * Effects in React 18 fire twice, and we are looking for a way to only fire it once.
     * - useInsertionEffect only fires once. If it's available we are in React 18.
     * - useLayoutEffect only fires once in React 17.
     *
     * Need to import it from React to fix React 17 ESM support.
     */
    const effectToUse = (_a = react_1.default.useInsertionEffect) !== null && _a !== void 0 ? _a : react_1.default.useLayoutEffect;
    if (typeof document !== 'undefined') {
        effectToUse(() => {
            if (ctx && ctx.numberOfAudioTags > 0) {
                ctx.updateAudio({ id: elem.id, aud, audioId, premounting, postmounting });
            }
        }, [aud, ctx, elem.id, audioId, premounting, postmounting]);
        effectToUse(() => {
            return () => {
                if (ctx && ctx.numberOfAudioTags > 0) {
                    ctx.unregisterAudio(elem.id);
                }
            };
        }, [ctx, elem.id]);
    }
    return elem;
};
exports.useSharedAudio = useSharedAudio;
