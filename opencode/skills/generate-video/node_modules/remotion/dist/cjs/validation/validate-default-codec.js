"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateCodec = validateCodec;
const codec_1 = require("../codec");
function validateCodec(defaultCodec, location, name) {
    if (typeof defaultCodec === 'undefined') {
        return;
    }
    if (typeof defaultCodec !== 'string') {
        throw new TypeError(`The "${name}" prop ${location} must be a string, but you passed a value of type ${typeof defaultCodec}.`);
    }
    if (!codec_1.validCodecs.includes(defaultCodec)) {
        throw new Error(`The "${name}" prop ${location} must be one of ${codec_1.validCodecs.join(', ')}, but you passed ${defaultCodec}.`);
    }
}
