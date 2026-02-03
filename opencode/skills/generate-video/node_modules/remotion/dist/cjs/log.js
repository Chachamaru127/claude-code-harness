"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Log = exports.isEqualOrBelowLogLevel = exports.logLevels = void 0;
const get_remotion_environment_1 = require("./get-remotion-environment");
/* eslint-disable no-console */
exports.logLevels = ['trace', 'verbose', 'info', 'warn', 'error'];
const getNumberForLogLevel = (level) => {
    return exports.logLevels.indexOf(level);
};
const isEqualOrBelowLogLevel = (currentLevel, level) => {
    return getNumberForLogLevel(currentLevel) <= getNumberForLogLevel(level);
};
exports.isEqualOrBelowLogLevel = isEqualOrBelowLogLevel;
const transformArgs = ({ args, logLevel, tag, }) => {
    const arr = [...args];
    if ((0, get_remotion_environment_1.getRemotionEnvironment)().isRendering &&
        !(0, get_remotion_environment_1.getRemotionEnvironment)().isClientSideRendering) {
        arr.unshift(Symbol.for(`__remotion_level_${logLevel}`));
    }
    if (tag &&
        (0, get_remotion_environment_1.getRemotionEnvironment)().isRendering &&
        !(0, get_remotion_environment_1.getRemotionEnvironment)().isClientSideRendering) {
        arr.unshift(Symbol.for(`__remotion_tag_${tag}`));
    }
    return arr;
};
const verbose = (options, ...args) => {
    if ((0, exports.isEqualOrBelowLogLevel)(options.logLevel, 'verbose')) {
        return console.debug(...transformArgs({ args, logLevel: 'verbose', tag: options.tag }));
    }
};
const trace = (options, ...args) => {
    if ((0, exports.isEqualOrBelowLogLevel)(options.logLevel, 'trace')) {
        return console.debug(...transformArgs({ args, logLevel: 'trace', tag: options.tag }));
    }
};
const info = (options, ...args) => {
    if ((0, exports.isEqualOrBelowLogLevel)(options.logLevel, 'info')) {
        return console.log(...transformArgs({ args, logLevel: 'info', tag: options.tag }));
    }
};
const warn = (options, ...args) => {
    if ((0, exports.isEqualOrBelowLogLevel)(options.logLevel, 'warn')) {
        return console.warn(...transformArgs({ args, logLevel: 'warn', tag: options.tag }));
    }
};
const error = (options, ...args) => {
    return console.error(...transformArgs({ args, logLevel: 'error', tag: options.tag }));
};
exports.Log = {
    trace,
    verbose,
    info,
    warn,
    error,
};
