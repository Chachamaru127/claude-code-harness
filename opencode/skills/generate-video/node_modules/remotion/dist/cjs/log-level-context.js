"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useMountTime = exports.useLogLevel = exports.LogLevelContext = void 0;
const react_1 = require("react");
const React = require("react");
exports.LogLevelContext = (0, react_1.createContext)({
    logLevel: 'info',
    mountTime: 0,
});
const useLogLevel = () => {
    const { logLevel } = React.useContext(exports.LogLevelContext);
    if (logLevel === null) {
        throw new Error('useLogLevel must be used within a LogLevelProvider');
    }
    return logLevel;
};
exports.useLogLevel = useLogLevel;
const useMountTime = () => {
    const { mountTime } = React.useContext(exports.LogLevelContext);
    if (mountTime === null) {
        throw new Error('useMountTime must be used within a LogLevelProvider');
    }
    return mountTime;
};
exports.useMountTime = useMountTime;
