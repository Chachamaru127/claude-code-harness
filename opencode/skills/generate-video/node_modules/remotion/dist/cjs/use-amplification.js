"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useVolume = void 0;
const react_1 = require("react");
const shared_audio_tags_1 = require("./audio/shared-audio-tags");
const is_approximately_the_same_1 = require("./is-approximately-the-same");
const log_1 = require("./log");
const video_fragment_1 = require("./video/video-fragment");
let warned = false;
const warnSafariOnce = (logLevel) => {
    if (warned) {
        return;
    }
    warned = true;
    log_1.Log.warn({ logLevel, tag: null }, 'In Safari, setting a volume and a playback rate at the same time is buggy.');
    log_1.Log.warn({ logLevel, tag: null }, 'In Desktop Safari, only volumes <= 1 will be applied.');
    log_1.Log.warn({ logLevel, tag: null }, logLevel, 'In Mobile Safari, the volume will be ignored and set to 1 if a playbackRate is set.');
};
/**
 * [1] Bug case: In Safari, you cannot combine playbackRate and volume !== 1.
 * If that is the case, volume will not be applied.
 */
const useVolume = ({ mediaRef, volume, logLevel, source, shouldUseWebAudioApi, }) => {
    var _a, _b, _c;
    const audioStuffRef = (0, react_1.useRef)(null);
    const currentVolumeRef = (0, react_1.useRef)(volume);
    currentVolumeRef.current = volume;
    const sharedAudioContext = (0, react_1.useContext)(shared_audio_tags_1.SharedAudioContext);
    if (!sharedAudioContext) {
        throw new Error('useAmplification must be used within a SharedAudioContext');
    }
    const { audioContext } = sharedAudioContext;
    if (typeof window !== 'undefined') {
        // eslint-disable-next-line react-hooks/rules-of-hooks
        (0, react_1.useLayoutEffect)(() => {
            var _a, _b;
            if (!audioContext) {
                return;
            }
            if (!mediaRef.current) {
                return;
            }
            if (!shouldUseWebAudioApi) {
                return;
            }
            // [1]
            if (mediaRef.current.playbackRate !== 1 && (0, video_fragment_1.isSafari)()) {
                warnSafariOnce(logLevel);
                return;
            }
            if (!source) {
                return;
            }
            const gainNode = new GainNode(audioContext, {
                gain: currentVolumeRef.current,
            });
            source.attemptToConnect();
            source.get().connect(gainNode);
            gainNode.connect(audioContext.destination);
            audioStuffRef.current = {
                gainNode,
            };
            log_1.Log.trace({ logLevel, tag: null }, `Starting to amplify ${(_a = mediaRef.current) === null || _a === void 0 ? void 0 : _a.src}. Gain = ${currentVolumeRef.current}, playbackRate = ${(_b = mediaRef.current) === null || _b === void 0 ? void 0 : _b.playbackRate}`);
            return () => {
                audioStuffRef.current = null;
                gainNode.disconnect();
                source.get().disconnect();
            };
        }, [logLevel, mediaRef, audioContext, source, shouldUseWebAudioApi]);
    }
    if (audioStuffRef.current) {
        const valueToSet = volume;
        if (!(0, is_approximately_the_same_1.isApproximatelyTheSame)(audioStuffRef.current.gainNode.gain.value, valueToSet)) {
            audioStuffRef.current.gainNode.gain.value = valueToSet;
            log_1.Log.trace({ logLevel, tag: null }, `Setting gain to ${valueToSet} for ${(_a = mediaRef.current) === null || _a === void 0 ? void 0 : _a.src}`);
        }
    }
    const safariCase = (0, video_fragment_1.isSafari)() && mediaRef.current && ((_b = mediaRef.current) === null || _b === void 0 ? void 0 : _b.playbackRate) !== 1;
    const shouldUseTraditionalVolume = safariCase || !shouldUseWebAudioApi;
    // [1]
    if (shouldUseTraditionalVolume &&
        mediaRef.current &&
        !(0, is_approximately_the_same_1.isApproximatelyTheSame)(volume, (_c = mediaRef.current) === null || _c === void 0 ? void 0 : _c.volume)) {
        mediaRef.current.volume = Math.min(volume, 1);
    }
    return audioStuffRef;
};
exports.useVolume = useVolume;
