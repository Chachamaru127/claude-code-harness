"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useDelayRender = exports.DelayRenderContextType = void 0;
const react_1 = require("react");
const cancel_render_js_1 = require("./cancel-render.js");
const delay_render_js_1 = require("./delay-render.js");
const log_level_context_js_1 = require("./log-level-context.js");
const use_remotion_environment_js_1 = require("./use-remotion-environment.js");
exports.DelayRenderContextType = (0, react_1.createContext)(null);
const useDelayRender = () => {
    var _a;
    const environment = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    const scope = (_a = (0, react_1.useContext)(exports.DelayRenderContextType)) !== null && _a !== void 0 ? _a : (typeof window !== 'undefined' ? window : undefined);
    const logLevel = (0, log_level_context_js_1.useLogLevel)();
    const delayRender = (0, react_1.useCallback)((label, options) => {
        if (!scope) {
            return Math.random();
        }
        return (0, delay_render_js_1.delayRenderInternal)({
            scope,
            environment,
            label: label !== null && label !== void 0 ? label : null,
            options: options !== null && options !== void 0 ? options : {},
        });
    }, [environment, scope]);
    const continueRender = (0, react_1.useCallback)((handle) => {
        if (!scope) {
            return;
        }
        (0, delay_render_js_1.continueRenderInternal)({
            scope,
            handle,
            environment,
            logLevel,
        });
    }, [environment, logLevel, scope]);
    const cancelRender = (0, react_1.useCallback)((err) => {
        return (0, cancel_render_js_1.cancelRenderInternal)(scope !== null && scope !== void 0 ? scope : (typeof window !== 'undefined' ? window : undefined), err);
    }, [scope]);
    return { delayRender, continueRender, cancelRender };
};
exports.useDelayRender = useDelayRender;
