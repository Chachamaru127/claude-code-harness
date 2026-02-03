"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAbsoluteSrc = void 0;
const getAbsoluteSrc = (relativeSrc) => {
    if (typeof window === 'undefined') {
        return relativeSrc;
    }
    // https://github.com/remotion-dev/remotion/issues/5359
    if (relativeSrc.startsWith('http://') ||
        relativeSrc.startsWith('https://') ||
        relativeSrc.startsWith('file://') ||
        relativeSrc.startsWith('blob:') ||
        relativeSrc.startsWith('data:')) {
        return relativeSrc;
    }
    return new URL(relativeSrc, window.origin).href;
};
exports.getAbsoluteSrc = getAbsoluteSrc;
