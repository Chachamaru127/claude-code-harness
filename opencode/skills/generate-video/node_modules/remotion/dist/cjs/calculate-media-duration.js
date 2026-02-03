"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.calculateMediaDuration = void 0;
const calculateMediaDuration = ({ trimAfter, mediaDurationInFrames, playbackRate, trimBefore, }) => {
    let duration = mediaDurationInFrames;
    // Account for trimAfter
    if (typeof trimAfter !== 'undefined') {
        duration = trimAfter;
    }
    // Account for trimBefore
    if (typeof trimBefore !== 'undefined') {
        duration -= trimBefore;
    }
    const actualDuration = duration / playbackRate;
    return Math.floor(actualDuration);
};
exports.calculateMediaDuration = calculateMediaDuration;
