"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useResolvedVideoConfig = exports.PROPS_UPDATED_EXTERNALLY = exports.needsResolution = exports.resolveCompositionsRef = exports.ResolveCompositionContext = void 0;
const react_1 = require("react");
const CompositionManagerContext_js_1 = require("./CompositionManagerContext.js");
const EditorProps_js_1 = require("./EditorProps.js");
const input_props_js_1 = require("./config/input-props.js");
const use_remotion_environment_js_1 = require("./use-remotion-environment.js");
const validate_dimensions_js_1 = require("./validation/validate-dimensions.js");
const validate_duration_in_frames_js_1 = require("./validation/validate-duration-in-frames.js");
const validate_fps_js_1 = require("./validation/validate-fps.js");
exports.ResolveCompositionContext = (0, react_1.createContext)(null);
exports.resolveCompositionsRef = (0, react_1.createRef)();
const needsResolution = (composition) => {
    return Boolean(composition.calculateMetadata);
};
exports.needsResolution = needsResolution;
exports.PROPS_UPDATED_EXTERNALLY = 'remotion.propsUpdatedExternally';
const useResolvedVideoConfig = (preferredCompositionId) => {
    const context = (0, react_1.useContext)(exports.ResolveCompositionContext);
    const { props: allEditorProps } = (0, react_1.useContext)(EditorProps_js_1.EditorPropsContext);
    const { compositions, canvasContent, currentCompositionMetadata } = (0, react_1.useContext)(CompositionManagerContext_js_1.CompositionManager);
    const currentComposition = (canvasContent === null || canvasContent === void 0 ? void 0 : canvasContent.type) === 'composition' ? canvasContent.compositionId : null;
    const compositionId = preferredCompositionId !== null && preferredCompositionId !== void 0 ? preferredCompositionId : currentComposition;
    const composition = compositions.find((c) => c.id === compositionId);
    const selectedEditorProps = (0, react_1.useMemo)(() => {
        var _a;
        return composition ? ((_a = allEditorProps[composition.id]) !== null && _a !== void 0 ? _a : {}) : {};
    }, [allEditorProps, composition]);
    const env = (0, use_remotion_environment_js_1.useRemotionEnvironment)();
    return (0, react_1.useMemo)(() => {
        var _a, _b, _c, _d;
        if (!composition) {
            return null;
        }
        if (currentCompositionMetadata) {
            return {
                type: 'success',
                result: {
                    ...currentCompositionMetadata,
                    id: composition.id,
                    defaultProps: (_a = composition.defaultProps) !== null && _a !== void 0 ? _a : {},
                },
            };
        }
        if (!(0, exports.needsResolution)(composition)) {
            (0, validate_duration_in_frames_js_1.validateDurationInFrames)(composition.durationInFrames, {
                allowFloats: false,
                component: `in <Composition id="${composition.id}">`,
            });
            (0, validate_fps_js_1.validateFps)(composition.fps, `in <Composition id="${composition.id}">`, false);
            (0, validate_dimensions_js_1.validateDimension)(composition.width, 'width', `in <Composition id="${composition.id}">`);
            (0, validate_dimensions_js_1.validateDimension)(composition.height, 'height', `in <Composition id="${composition.id}">`);
            return {
                type: 'success',
                result: {
                    width: composition.width,
                    height: composition.height,
                    fps: composition.fps,
                    id: composition.id,
                    durationInFrames: composition.durationInFrames,
                    defaultProps: (_b = composition.defaultProps) !== null && _b !== void 0 ? _b : {},
                    props: {
                        ...((_c = composition.defaultProps) !== null && _c !== void 0 ? _c : {}),
                        ...(selectedEditorProps !== null && selectedEditorProps !== void 0 ? selectedEditorProps : {}),
                        ...(typeof window === 'undefined' ||
                            env.isPlayer ||
                            // In tests, we don't set window.remotion_inputProps,
                            // otherwise it should be available here
                            !window.remotion_inputProps
                            ? {}
                            : ((_d = (0, input_props_js_1.getInputProps)()) !== null && _d !== void 0 ? _d : {})),
                    },
                    defaultCodec: null,
                    defaultOutName: null,
                    defaultVideoImageFormat: null,
                    defaultPixelFormat: null,
                    defaultProResProfile: null,
                },
            };
        }
        // Could be the case in selectComposition()
        if (!context) {
            return null;
        }
        if (!context[composition.id]) {
            return null;
        }
        return context[composition.id];
    }, [
        composition,
        context,
        currentCompositionMetadata,
        selectedEditorProps,
        env.isPlayer,
    ]);
};
exports.useResolvedVideoConfig = useResolvedVideoConfig;
