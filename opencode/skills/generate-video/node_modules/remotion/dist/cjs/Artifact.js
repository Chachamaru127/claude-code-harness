"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Artifact = void 0;
const react_1 = require("react");
const RenderAssetManager_1 = require("./RenderAssetManager");
const use_current_frame_1 = require("./use-current-frame");
const use_remotion_environment_1 = require("./use-remotion-environment");
const ArtifactThumbnail = Symbol('Thumbnail');
const Artifact = ({ filename, content, downloadBehavior }) => {
    const { registerRenderAsset, unregisterRenderAsset } = (0, react_1.useContext)(RenderAssetManager_1.RenderAssetManager);
    const env = (0, use_remotion_environment_1.useRemotionEnvironment)();
    const frame = (0, use_current_frame_1.useCurrentFrame)();
    const [id] = (0, react_1.useState)(() => {
        return String(Math.random());
    });
    (0, react_1.useLayoutEffect)(() => {
        if (!env.isRendering) {
            return;
        }
        if (content instanceof Uint8Array) {
            registerRenderAsset({
                type: 'artifact',
                id,
                content: btoa(new TextDecoder('utf8').decode(content)),
                filename,
                frame,
                contentType: 'binary',
                downloadBehavior: downloadBehavior !== null && downloadBehavior !== void 0 ? downloadBehavior : null,
            });
        }
        else if (content === ArtifactThumbnail) {
            registerRenderAsset({
                type: 'artifact',
                id,
                filename,
                frame,
                contentType: 'thumbnail',
                downloadBehavior: downloadBehavior !== null && downloadBehavior !== void 0 ? downloadBehavior : null,
            });
        }
        else {
            registerRenderAsset({
                type: 'artifact',
                id,
                content,
                filename,
                frame,
                contentType: 'text',
                downloadBehavior: downloadBehavior !== null && downloadBehavior !== void 0 ? downloadBehavior : null,
            });
        }
        return () => {
            return unregisterRenderAsset(id);
        };
    }, [
        content,
        env.isRendering,
        filename,
        frame,
        id,
        registerRenderAsset,
        unregisterRenderAsset,
        downloadBehavior,
    ]);
    return null;
};
exports.Artifact = Artifact;
exports.Artifact.Thumbnail = ArtifactThumbnail;
