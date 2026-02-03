export declare const validVideoImageFormats: readonly ["png", "jpeg", "none"];
export type VideoImageFormat = (typeof validVideoImageFormats)[number];
export declare const validPixelFormats: readonly ["yuv420p", "yuva420p", "yuv422p", "yuv444p", "yuv420p10le", "yuv422p10le", "yuv444p10le", "yuva444p10le"];
export type PixelFormat = (typeof validPixelFormats)[number];
