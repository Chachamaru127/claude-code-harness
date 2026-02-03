"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.addSequenceStackTraces = exports.enableSequenceStackTraces = void 0;
const react_1 = __importDefault(require("react"));
const jsx_runtime_1 = __importDefault(require("react/jsx-runtime"));
const get_remotion_environment_1 = require("./get-remotion-environment");
const originalCreateElement = react_1.default.createElement;
const originalJsx = jsx_runtime_1.default.jsx;
const componentsToAddStacksTo = [];
const enableProxy = (api) => {
    return new Proxy(api, {
        apply(target, thisArg, argArray) {
            if (componentsToAddStacksTo.includes(argArray[0])) {
                const [first, props, ...rest] = argArray;
                const newProps = {
                    ...(props !== null && props !== void 0 ? props : {}),
                    stack: new Error().stack,
                };
                return Reflect.apply(target, thisArg, [first, newProps, ...rest]);
            }
            return Reflect.apply(target, thisArg, argArray);
        },
    });
};
// Gets called when a new component is added,
// also when the Studio is mounted
const enableSequenceStackTraces = () => {
    if (!(0, get_remotion_environment_1.getRemotionEnvironment)().isStudio) {
        return;
    }
    react_1.default.createElement = enableProxy(originalCreateElement);
    jsx_runtime_1.default.jsx = enableProxy(originalJsx);
};
exports.enableSequenceStackTraces = enableSequenceStackTraces;
const addSequenceStackTraces = (component) => {
    componentsToAddStacksTo.push(component);
    (0, exports.enableSequenceStackTraces)();
};
exports.addSequenceStackTraces = addSequenceStackTraces;
