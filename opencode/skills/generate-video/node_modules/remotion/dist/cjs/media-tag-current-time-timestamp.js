"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.useCurrentTimeOfMediaTagWithUpdateTimeStamp = void 0;
const react_1 = __importDefault(require("react"));
const useCurrentTimeOfMediaTagWithUpdateTimeStamp = (mediaRef) => {
    var _a, _b, _c, _d;
    const lastUpdate = react_1.default.useRef({
        time: (_b = (_a = mediaRef.current) === null || _a === void 0 ? void 0 : _a.currentTime) !== null && _b !== void 0 ? _b : 0,
        lastUpdate: performance.now(),
    });
    const nowCurrentTime = (_d = (_c = mediaRef.current) === null || _c === void 0 ? void 0 : _c.currentTime) !== null && _d !== void 0 ? _d : null;
    if (nowCurrentTime !== null) {
        if (lastUpdate.current.time !== nowCurrentTime) {
            lastUpdate.current.time = nowCurrentTime;
            lastUpdate.current.lastUpdate = performance.now();
        }
    }
    return lastUpdate;
};
exports.useCurrentTimeOfMediaTagWithUpdateTimeStamp = useCurrentTimeOfMediaTagWithUpdateTimeStamp;
