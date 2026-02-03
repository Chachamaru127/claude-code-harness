"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveVideoConfigOrCatch = exports.resolveVideoConfig = void 0;
const get_remotion_environment_js_1 = require("./get-remotion-environment.js");
const input_props_serialization_js_1 = require("./input-props-serialization.js");
const validate_default_codec_js_1 = require("./validation/validate-default-codec.js");
const validate_dimensions_js_1 = require("./validation/validate-dimensions.js");
const validate_duration_in_frames_js_1 = require("./validation/validate-duration-in-frames.js");
const validate_fps_js_1 = require("./validation/validate-fps.js");
const validateCalculated = ({ calculated, compositionId, compositionFps, compositionHeight, compositionWidth, compositionDurationInFrames, }) => {
    var _a, _b, _c, _d, _e, _f, _g, _h;
    const calculateMetadataErrorLocation = `calculated by calculateMetadata() for the composition "${compositionId}"`;
    const defaultErrorLocation = `of the "<Composition />" component with the id "${compositionId}"`;
    const width = (_b = (_a = calculated === null || calculated === void 0 ? void 0 : calculated.width) !== null && _a !== void 0 ? _a : compositionWidth) !== null && _b !== void 0 ? _b : undefined;
    (0, validate_dimensions_js_1.validateDimension)(width, 'width', (calculated === null || calculated === void 0 ? void 0 : calculated.width) ? calculateMetadataErrorLocation : defaultErrorLocation);
    const height = (_d = (_c = calculated === null || calculated === void 0 ? void 0 : calculated.height) !== null && _c !== void 0 ? _c : compositionHeight) !== null && _d !== void 0 ? _d : undefined;
    (0, validate_dimensions_js_1.validateDimension)(height, 'height', (calculated === null || calculated === void 0 ? void 0 : calculated.height) ? calculateMetadataErrorLocation : defaultErrorLocation);
    const fps = (_f = (_e = calculated === null || calculated === void 0 ? void 0 : calculated.fps) !== null && _e !== void 0 ? _e : compositionFps) !== null && _f !== void 0 ? _f : null;
    (0, validate_fps_js_1.validateFps)(fps, (calculated === null || calculated === void 0 ? void 0 : calculated.fps) ? calculateMetadataErrorLocation : defaultErrorLocation, false);
    const durationInFrames = (_h = (_g = calculated === null || calculated === void 0 ? void 0 : calculated.durationInFrames) !== null && _g !== void 0 ? _g : compositionDurationInFrames) !== null && _h !== void 0 ? _h : null;
    (0, validate_duration_in_frames_js_1.validateDurationInFrames)(durationInFrames, {
        allowFloats: false,
        component: `of the "<Composition />" component with the id "${compositionId}"`,
    });
    const defaultCodec = calculated === null || calculated === void 0 ? void 0 : calculated.defaultCodec;
    (0, validate_default_codec_js_1.validateCodec)(defaultCodec, calculateMetadataErrorLocation, 'defaultCodec');
    const defaultOutName = calculated === null || calculated === void 0 ? void 0 : calculated.defaultOutName;
    const defaultVideoImageFormat = calculated === null || calculated === void 0 ? void 0 : calculated.defaultVideoImageFormat;
    const defaultPixelFormat = calculated === null || calculated === void 0 ? void 0 : calculated.defaultPixelFormat;
    const defaultProResProfile = calculated === null || calculated === void 0 ? void 0 : calculated.defaultProResProfile;
    return {
        width,
        height,
        fps,
        durationInFrames,
        defaultCodec,
        defaultOutName,
        defaultVideoImageFormat,
        defaultPixelFormat,
        defaultProResProfile,
    };
};
const resolveVideoConfig = ({ calculateMetadata, signal, defaultProps, inputProps: originalProps, compositionId, compositionDurationInFrames, compositionFps, compositionHeight, compositionWidth, }) => {
    var _a, _b, _c, _d, _e, _f;
    const calculatedProm = calculateMetadata
        ? calculateMetadata({
            defaultProps,
            props: originalProps,
            abortSignal: signal,
            compositionId,
            isRendering: (0, get_remotion_environment_js_1.getRemotionEnvironment)().isRendering,
        })
        : null;
    if (calculatedProm !== null &&
        typeof calculatedProm === 'object' &&
        'then' in calculatedProm) {
        return calculatedProm.then((c) => {
            var _a;
            const { height, width, durationInFrames, fps, defaultCodec, defaultOutName, defaultVideoImageFormat, defaultPixelFormat, defaultProResProfile, } = validateCalculated({
                calculated: c,
                compositionDurationInFrames,
                compositionFps,
                compositionHeight,
                compositionWidth,
                compositionId,
            });
            return {
                width,
                height,
                fps,
                durationInFrames,
                id: compositionId,
                defaultProps: (0, input_props_serialization_js_1.serializeThenDeserializeInStudio)(defaultProps),
                props: (0, input_props_serialization_js_1.serializeThenDeserializeInStudio)((_a = c.props) !== null && _a !== void 0 ? _a : originalProps),
                defaultCodec: defaultCodec !== null && defaultCodec !== void 0 ? defaultCodec : null,
                defaultOutName: defaultOutName !== null && defaultOutName !== void 0 ? defaultOutName : null,
                defaultVideoImageFormat: defaultVideoImageFormat !== null && defaultVideoImageFormat !== void 0 ? defaultVideoImageFormat : null,
                defaultPixelFormat: defaultPixelFormat !== null && defaultPixelFormat !== void 0 ? defaultPixelFormat : null,
                defaultProResProfile: defaultProResProfile !== null && defaultProResProfile !== void 0 ? defaultProResProfile : null,
            };
        });
    }
    const data = validateCalculated({
        calculated: calculatedProm,
        compositionDurationInFrames,
        compositionFps,
        compositionHeight,
        compositionWidth,
        compositionId,
    });
    if (calculatedProm === null) {
        return {
            ...data,
            id: compositionId,
            defaultProps: (0, input_props_serialization_js_1.serializeThenDeserializeInStudio)(defaultProps !== null && defaultProps !== void 0 ? defaultProps : {}),
            props: (0, input_props_serialization_js_1.serializeThenDeserializeInStudio)(originalProps),
            defaultCodec: null,
            defaultOutName: null,
            defaultVideoImageFormat: null,
            defaultPixelFormat: null,
            defaultProResProfile: null,
        };
    }
    return {
        ...data,
        id: compositionId,
        defaultProps: (0, input_props_serialization_js_1.serializeThenDeserializeInStudio)(defaultProps !== null && defaultProps !== void 0 ? defaultProps : {}),
        props: (0, input_props_serialization_js_1.serializeThenDeserializeInStudio)((_a = calculatedProm.props) !== null && _a !== void 0 ? _a : originalProps),
        defaultCodec: (_b = calculatedProm.defaultCodec) !== null && _b !== void 0 ? _b : null,
        defaultOutName: (_c = calculatedProm.defaultOutName) !== null && _c !== void 0 ? _c : null,
        defaultVideoImageFormat: (_d = calculatedProm.defaultVideoImageFormat) !== null && _d !== void 0 ? _d : null,
        defaultPixelFormat: (_e = calculatedProm.defaultPixelFormat) !== null && _e !== void 0 ? _e : null,
        defaultProResProfile: (_f = calculatedProm.defaultProResProfile) !== null && _f !== void 0 ? _f : null,
    };
};
exports.resolveVideoConfig = resolveVideoConfig;
const resolveVideoConfigOrCatch = (params) => {
    try {
        const promiseOrReturnValue = (0, exports.resolveVideoConfig)(params);
        return {
            type: 'success',
            result: promiseOrReturnValue,
        };
    }
    catch (err) {
        return {
            type: 'error',
            error: err,
        };
    }
};
exports.resolveVideoConfigOrCatch = resolveVideoConfigOrCatch;
