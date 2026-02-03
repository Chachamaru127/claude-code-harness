"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useSingletonAudioContext = void 0;
const react_1 = require("react");
const log_1 = require("../log");
const use_remotion_environment_1 = require("../use-remotion-environment");
let warned = false;
const warnOnce = (logLevel) => {
    if (warned) {
        return;
    }
    warned = true;
    // Don't pullute logs if in SSR
    if (typeof window !== 'undefined') {
        log_1.Log.warn({ logLevel, tag: null }, 'AudioContext is not supported in this browser');
    }
};
const useSingletonAudioContext = ({ logLevel, latencyHint, audioEnabled, }) => {
    const env = (0, use_remotion_environment_1.useRemotionEnvironment)();
    const audioContext = (0, react_1.useMemo)(() => {
        if (env.isRendering) {
            return null;
        }
        if (!audioEnabled) {
            return null;
        }
        if (typeof AudioContext === 'undefined') {
            warnOnce(logLevel);
            return null;
        }
        return new AudioContext({
            latencyHint,
            // By default, this can end up being 44100Hz.
            // Playing a 48000Hz file in a 44100Hz context, such as https://remotion.media/video.mp4 in a @remotion/media tag
            // we observe some issues that seem to go away when we set the sample rate to 48000 with Sony LinkBuds Bluetooth headphones.
            sampleRate: 48000,
        });
    }, [logLevel, latencyHint, env.isRendering, audioEnabled]);
    return audioContext;
};
exports.useSingletonAudioContext = useSingletonAudioContext;
