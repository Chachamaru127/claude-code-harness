"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.warnAboutTooHighVolume = void 0;
const warnAboutTooHighVolume = (volume) => {
    if (volume >= 100) {
        throw new Error(`Volume was set to ${volume}, but regular volume is 1, not 100. Did you forget to divide by 100? Set a volume of less than 100 to dismiss this error.`);
    }
};
exports.warnAboutTooHighVolume = warnAboutTooHighVolume;
