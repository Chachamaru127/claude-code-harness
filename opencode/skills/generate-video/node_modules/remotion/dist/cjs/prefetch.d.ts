import type { LogLevel } from './log.js';
export declare const removeAndGetHashFragment: (src: string) => number | null;
export declare const getSrcWithoutHash: (src: string) => string;
export declare const usePreload: (src: string) => string;
type FetchAndPreload = {
    free: () => void;
    waitUntilDone: () => Promise<string>;
};
export type PrefetchOnProgress = (options: {
    totalBytes: number | null;
    loadedBytes: number;
}) => void;
export declare const prefetch: (src: string, options?: {
    method?: "blob-url" | "base64";
    contentType?: string;
    onProgress?: PrefetchOnProgress;
    credentials?: RequestCredentials;
    logLevel?: LogLevel;
}) => FetchAndPreload;
export {};
