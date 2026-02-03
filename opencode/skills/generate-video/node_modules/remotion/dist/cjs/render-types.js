"use strict";
// Types copied from @remotion/renderer for use in core composition metadata
// This avoids circular dependencies while keeping renderer as the source of truth
Object.defineProperty(exports, "__esModule", { value: true });
exports.validPixelFormats = exports.validVideoImageFormats = void 0;
exports.validVideoImageFormats = ['png', 'jpeg', 'none'];
exports.validPixelFormats = [
    'yuv420p',
    'yuva420p',
    'yuv422p',
    'yuv444p',
    'yuv420p10le',
    'yuv422p10le',
    'yuv444p10le',
    'yuva444p10le',
];
