"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.playbackLogging = void 0;
const log_1 = require("./log");
const playbackLogging = ({ logLevel, tag, message, mountTime, }) => {
    const tags = [mountTime ? Date.now() - mountTime + 'ms ' : null, tag]
        .filter(Boolean)
        .join(' ');
    log_1.Log.trace({ logLevel, tag: null }, `[${tags}]`, message);
};
exports.playbackLogging = playbackLogging;
