import type React from 'react';
import type { DownloadBehavior } from './download-behavior';
declare const ArtifactThumbnail: unique symbol;
export declare const Artifact: React.FC<{
    readonly filename: string;
    readonly content: string | Uint8Array | typeof ArtifactThumbnail;
    readonly downloadBehavior?: DownloadBehavior | null;
}> & {
    Thumbnail: typeof ArtifactThumbnail;
};
export {};
