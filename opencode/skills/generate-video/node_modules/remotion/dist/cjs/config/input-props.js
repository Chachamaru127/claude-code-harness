"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getInputProps = void 0;
const get_remotion_environment_js_1 = require("../get-remotion-environment.js");
const input_props_override_js_1 = require("../input-props-override.js");
const input_props_serialization_js_1 = require("../input-props-serialization.js");
let didWarnSSRImport = false;
const warnOnceSSRImport = () => {
    if (didWarnSSRImport) {
        return;
    }
    didWarnSSRImport = true;
    // eslint-disable-next-line no-console
    console.warn('Called `getInputProps()` on the server. This function is not available server-side and has returned an empty object.');
    // eslint-disable-next-line no-console
    console.warn("To hide this warning, don't call this function on the server:");
    // eslint-disable-next-line no-console
    console.warn("  typeof window === 'undefined' ? {} : getInputProps()");
};
const getInputProps = () => {
    if (typeof window === 'undefined') {
        warnOnceSSRImport();
        return {};
    }
    if ((0, get_remotion_environment_js_1.getRemotionEnvironment)().isPlayer) {
        throw new Error('You cannot call `getInputProps()` from a <Player>. Instead, the props are available as React props from component that you passed as `component` prop.');
    }
    const override = (0, input_props_override_js_1.getInputPropsOverride)();
    if (override) {
        return override;
    }
    if (typeof window === 'undefined' ||
        typeof window.remotion_inputProps === 'undefined') {
        throw new Error('Cannot call `getInputProps()` - window.remotion_inputProps is not set. This API is only available if you are in the Studio, or while you are rendering server-side.');
    }
    const param = window.remotion_inputProps;
    if (!param) {
        return {};
    }
    const parsed = (0, input_props_serialization_js_1.deserializeJSONWithSpecialTypes)(param);
    return parsed;
};
exports.getInputProps = getInputProps;
