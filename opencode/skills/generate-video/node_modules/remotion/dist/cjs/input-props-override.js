"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.setInputPropsOverride = exports.getInputPropsOverride = void 0;
const getKey = () => {
    return `remotion_inputPropsOverride` + window.location.origin;
};
const getInputPropsOverride = () => {
    if (typeof localStorage === 'undefined')
        return null;
    const override = localStorage.getItem(getKey());
    if (!override)
        return null;
    return JSON.parse(override);
};
exports.getInputPropsOverride = getInputPropsOverride;
const setInputPropsOverride = (override) => {
    if (typeof localStorage === 'undefined')
        return;
    if (override === null) {
        localStorage.removeItem(getKey());
        return;
    }
    localStorage.setItem(getKey(), JSON.stringify(override));
};
exports.setInputPropsOverride = setInputPropsOverride;
