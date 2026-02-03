"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.useCurrentScale = exports.calculateScale = exports.PreviewSizeContext = exports.CurrentScaleContext = void 0;
const react_1 = __importStar(require("react"));
const use_remotion_environment_1 = require("./use-remotion-environment");
const use_unsafe_video_config_1 = require("./use-unsafe-video-config");
exports.CurrentScaleContext = react_1.default.createContext(null);
exports.PreviewSizeContext = (0, react_1.createContext)({
    setSize: () => undefined,
    size: { size: 'auto', translation: { x: 0, y: 0 } },
});
const calculateScale = ({ canvasSize, compositionHeight, compositionWidth, previewSize, }) => {
    const heightRatio = canvasSize.height / compositionHeight;
    const widthRatio = canvasSize.width / compositionWidth;
    const ratio = Math.min(heightRatio, widthRatio);
    if (previewSize === 'auto') {
        // Container may be 0x0 because it doesn't have any content yet.
        if (ratio === 0) {
            return 1;
        }
        return ratio;
    }
    return Number(previewSize);
};
exports.calculateScale = calculateScale;
/*
 * @description Retrieves the current scale of the canvas within Remotion's Studio or Player context. In the Studio, it corresponds to the zoom level (1 equals no scaling, i.e., 100% zoom). In the Player, it indicates the scaling necessary to fit the video into the player. If called outside of a Remotion context, by default, it throws an error unless configured not to.
 * @see [Documentation](https://www.remotion.dev/docs/use-current-scale)
 */
const useCurrentScale = (options) => {
    const hasContext = react_1.default.useContext(exports.CurrentScaleContext);
    const zoomContext = react_1.default.useContext(exports.PreviewSizeContext);
    const config = (0, use_unsafe_video_config_1.useUnsafeVideoConfig)();
    const env = (0, use_remotion_environment_1.useRemotionEnvironment)();
    if (hasContext === null || config === null || zoomContext === null) {
        if (options === null || options === void 0 ? void 0 : options.dontThrowIfOutsideOfRemotion) {
            return 1;
        }
        if (env.isRendering) {
            return 1;
        }
        throw new Error([
            'useCurrentScale() was called outside of a Remotion context.',
            'This hook can only be called in a component that is being rendered by Remotion.',
            'If you want to this hook to return 1 outside of Remotion, pass {dontThrowIfOutsideOfRemotion: true} as an option.',
            'If you think you called this hook in a Remotion component, make sure all versions of Remotion are aligned.',
        ].join('\n'));
    }
    if (hasContext.type === 'scale') {
        return hasContext.scale;
    }
    return (0, exports.calculateScale)({
        canvasSize: hasContext.canvasSize,
        compositionHeight: config.height,
        compositionWidth: config.width,
        previewSize: zoomContext.size.size,
    });
};
exports.useCurrentScale = useCurrentScale;
