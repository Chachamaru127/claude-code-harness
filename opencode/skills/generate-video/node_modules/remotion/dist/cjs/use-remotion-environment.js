"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useRemotionEnvironment = void 0;
const react_1 = require("react");
const get_remotion_environment_1 = require("./get-remotion-environment");
const remotion_environment_context_1 = require("./remotion-environment-context");
/**
 * @description A React hook that provides information about the current Remotion Environment. This is the preferred way to access environment information in React components as it will support future scoped contexts.
 * @see [Documentation](https://remotion.dev/docs/use-remotion-environment)
 */
const useRemotionEnvironment = () => {
    const context = (0, react_1.useContext)(remotion_environment_context_1.RemotionEnvironmentContext);
    const [env] = (0, react_1.useState)(() => (0, get_remotion_environment_1.getRemotionEnvironment)());
    return context !== null && context !== void 0 ? context : env;
};
exports.useRemotionEnvironment = useRemotionEnvironment;
