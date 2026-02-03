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
exports.Internals = void 0;
const react_1 = require("react");
const absolute_src_js_1 = require("./absolute-src.js");
const AudioForPreview_js_1 = require("./audio/AudioForPreview.js");
const shared_audio_tags_js_1 = require("./audio/shared-audio-tags.js");
const use_audio_frame_js_1 = require("./audio/use-audio-frame.js");
const buffering_js_1 = require("./buffering.js");
const calculate_media_duration_js_1 = require("./calculate-media-duration.js");
const CanUseRemotionHooks_js_1 = require("./CanUseRemotionHooks.js");
const CompositionManager_js_1 = require("./CompositionManager.js");
const CompositionManagerContext_js_1 = require("./CompositionManagerContext.js");
const CompositionManagerProvider_js_1 = require("./CompositionManagerProvider.js");
const CSSUtils = __importStar(require("./default-css.js"));
const default_css_js_1 = require("./default-css.js");
const EditorProps_js_1 = require("./EditorProps.js");
const enable_sequence_stack_traces_js_1 = require("./enable-sequence-stack-traces.js");
const get_preview_dom_element_js_1 = require("./get-preview-dom-element.js");
const get_remotion_environment_js_1 = require("./get-remotion-environment.js");
const input_props_override_js_1 = require("./input-props-override.js");
const is_player_js_1 = require("./is-player.js");
const log_level_context_js_1 = require("./log-level-context.js");
const log_js_1 = require("./log.js");
const max_video_cache_size_js_1 = require("./max-video-cache-size.js");
const nonce_js_1 = require("./nonce.js");
const playback_logging_js_1 = require("./playback-logging.js");
const portal_node_js_1 = require("./portal-node.js");
const prefetch_state_js_1 = require("./prefetch-state.js");
const prefetch_js_1 = require("./prefetch.js");
const register_root_js_1 = require("./register-root.js");
const remotion_environment_context_js_1 = require("./remotion-environment-context.js");
const RemotionRoot_js_1 = require("./RemotionRoot.js");
const RenderAssetManager_js_1 = require("./RenderAssetManager.js");
const resolve_video_config_js_1 = require("./resolve-video-config.js");
const ResolveCompositionConfig_js_1 = require("./ResolveCompositionConfig.js");
const SequenceContext_js_1 = require("./SequenceContext.js");
const SequenceManager_js_1 = require("./SequenceManager.js");
const setup_env_variables_js_1 = require("./setup-env-variables.js");
const TimelinePosition = __importStar(require("./timeline-position-state.js"));
const timeline_position_state_js_1 = require("./timeline-position-state.js");
const TimelineContext_js_1 = require("./TimelineContext.js");
const truthy_js_1 = require("./truthy.js");
const use_current_scale_js_1 = require("./use-current-scale.js");
const use_delay_render_js_1 = require("./use-delay-render.js");
const use_lazy_component_js_1 = require("./use-lazy-component.js");
const use_media_enabled_js_1 = require("./use-media-enabled.js");
const use_media_in_timeline_js_1 = require("./use-media-in-timeline.js");
const use_unsafe_video_config_js_1 = require("./use-unsafe-video-config.js");
const use_video_js_1 = require("./use-video.js");
const validate_media_props_js_1 = require("./validate-media-props.js");
const validate_start_from_props_js_1 = require("./validate-start-from-props.js");
const validate_artifact_js_1 = require("./validation/validate-artifact.js");
const validate_composition_id_js_1 = require("./validation/validate-composition-id.js");
const duration_state_js_1 = require("./video/duration-state.js");
const OffthreadVideo_js_1 = require("./video/OffthreadVideo.js");
const video_fragment_js_1 = require("./video/video-fragment.js");
const VideoForPreview_js_1 = require("./video/VideoForPreview.js");
const volume_position_state_js_1 = require("./volume-position-state.js");
const volume_prop_js_1 = require("./volume-prop.js");
const volume_safeguard_js_1 = require("./volume-safeguard.js");
const watch_static_file_js_1 = require("./watch-static-file.js");
const wrap_remotion_context_js_1 = require("./wrap-remotion-context.js");
// needs to be in core package so gets deduplicated in studio
const compositionSelectorRef = (0, react_1.createRef)();
// Mark them as Internals so use don't assume this is public
// API and are less likely to use it
exports.Internals = {
    MaxMediaCacheSizeContext: max_video_cache_size_js_1.MaxMediaCacheSizeContext,
    useUnsafeVideoConfig: use_unsafe_video_config_js_1.useUnsafeVideoConfig,
    useFrameForVolumeProp: use_audio_frame_js_1.useFrameForVolumeProp,
    useTimelinePosition: TimelinePosition.useTimelinePosition,
    evaluateVolume: volume_prop_js_1.evaluateVolume,
    getAbsoluteSrc: absolute_src_js_1.getAbsoluteSrc,
    Timeline: TimelinePosition,
    validateMediaTrimProps: validate_start_from_props_js_1.validateMediaTrimProps,
    validateMediaProps: validate_media_props_js_1.validateMediaProps,
    resolveTrimProps: validate_start_from_props_js_1.resolveTrimProps,
    VideoForPreview: VideoForPreview_js_1.VideoForPreview,
    CompositionManager: CompositionManagerContext_js_1.CompositionManager,
    CompositionSetters: CompositionManagerContext_js_1.CompositionSetters,
    SequenceManager: SequenceManager_js_1.SequenceManager,
    SequenceVisibilityToggleContext: SequenceManager_js_1.SequenceVisibilityToggleContext,
    RemotionRootContexts: RemotionRoot_js_1.RemotionRootContexts,
    CompositionManagerProvider: CompositionManagerProvider_js_1.CompositionManagerProvider,
    useVideo: use_video_js_1.useVideo,
    getRoot: register_root_js_1.getRoot,
    useMediaVolumeState: volume_position_state_js_1.useMediaVolumeState,
    useMediaMutedState: volume_position_state_js_1.useMediaMutedState,
    useMediaInTimeline: use_media_in_timeline_js_1.useMediaInTimeline,
    useLazyComponent: use_lazy_component_js_1.useLazyComponent,
    truthy: truthy_js_1.truthy,
    SequenceContext: SequenceContext_js_1.SequenceContext,
    useRemotionContexts: wrap_remotion_context_js_1.useRemotionContexts,
    RemotionContextProvider: wrap_remotion_context_js_1.RemotionContextProvider,
    CSSUtils,
    setupEnvVariables: setup_env_variables_js_1.setupEnvVariables,
    MediaVolumeContext: volume_position_state_js_1.MediaVolumeContext,
    SetMediaVolumeContext: volume_position_state_js_1.SetMediaVolumeContext,
    getRemotionEnvironment: get_remotion_environment_js_1.getRemotionEnvironment,
    SharedAudioContext: shared_audio_tags_js_1.SharedAudioContext,
    SharedAudioContextProvider: shared_audio_tags_js_1.SharedAudioContextProvider,
    invalidCompositionErrorMessage: validate_composition_id_js_1.invalidCompositionErrorMessage,
    calculateMediaDuration: calculate_media_duration_js_1.calculateMediaDuration,
    isCompositionIdValid: validate_composition_id_js_1.isCompositionIdValid,
    getPreviewDomElement: get_preview_dom_element_js_1.getPreviewDomElement,
    compositionsRef: CompositionManager_js_1.compositionsRef,
    portalNode: portal_node_js_1.portalNode,
    waitForRoot: register_root_js_1.waitForRoot,
    SetTimelineContext: TimelineContext_js_1.SetTimelineContext,
    CanUseRemotionHooksProvider: CanUseRemotionHooks_js_1.CanUseRemotionHooksProvider,
    CanUseRemotionHooks: CanUseRemotionHooks_js_1.CanUseRemotionHooks,
    PrefetchProvider: prefetch_state_js_1.PrefetchProvider,
    DurationsContextProvider: duration_state_js_1.DurationsContextProvider,
    IsPlayerContextProvider: is_player_js_1.IsPlayerContextProvider,
    useIsPlayer: is_player_js_1.useIsPlayer,
    EditorPropsProvider: EditorProps_js_1.EditorPropsProvider,
    EditorPropsContext: EditorProps_js_1.EditorPropsContext,
    usePreload: prefetch_js_1.usePreload,
    NonceContext: nonce_js_1.NonceContext,
    resolveVideoConfig: resolve_video_config_js_1.resolveVideoConfig,
    resolveVideoConfigOrCatch: resolve_video_config_js_1.resolveVideoConfigOrCatch,
    ResolveCompositionContext: ResolveCompositionConfig_js_1.ResolveCompositionContext,
    useResolvedVideoConfig: ResolveCompositionConfig_js_1.useResolvedVideoConfig,
    resolveCompositionsRef: ResolveCompositionConfig_js_1.resolveCompositionsRef,
    REMOTION_STUDIO_CONTAINER_ELEMENT: get_preview_dom_element_js_1.REMOTION_STUDIO_CONTAINER_ELEMENT,
    RenderAssetManager: RenderAssetManager_js_1.RenderAssetManager,
    persistCurrentFrame: timeline_position_state_js_1.persistCurrentFrame,
    useTimelineSetFrame: timeline_position_state_js_1.useTimelineSetFrame,
    isIosSafari: video_fragment_js_1.isIosSafari,
    WATCH_REMOTION_STATIC_FILES: watch_static_file_js_1.WATCH_REMOTION_STATIC_FILES,
    addSequenceStackTraces: enable_sequence_stack_traces_js_1.addSequenceStackTraces,
    useMediaStartsAt: use_audio_frame_js_1.useMediaStartsAt,
    BufferingProvider: buffering_js_1.BufferingProvider,
    BufferingContextReact: buffering_js_1.BufferingContextReact,
    enableSequenceStackTraces: enable_sequence_stack_traces_js_1.enableSequenceStackTraces,
    CurrentScaleContext: use_current_scale_js_1.CurrentScaleContext,
    PreviewSizeContext: use_current_scale_js_1.PreviewSizeContext,
    calculateScale: use_current_scale_js_1.calculateScale,
    editorPropsProviderRef: EditorProps_js_1.editorPropsProviderRef,
    PROPS_UPDATED_EXTERNALLY: ResolveCompositionConfig_js_1.PROPS_UPDATED_EXTERNALLY,
    validateRenderAsset: validate_artifact_js_1.validateRenderAsset,
    Log: log_js_1.Log,
    LogLevelContext: log_level_context_js_1.LogLevelContext,
    useLogLevel: log_level_context_js_1.useLogLevel,
    playbackLogging: playback_logging_js_1.playbackLogging,
    timeValueRef: EditorProps_js_1.timeValueRef,
    compositionSelectorRef,
    RemotionEnvironmentContext: remotion_environment_context_js_1.RemotionEnvironmentContext,
    warnAboutTooHighVolume: volume_safeguard_js_1.warnAboutTooHighVolume,
    AudioForPreview: AudioForPreview_js_1.AudioForPreview,
    OBJECTFIT_CONTAIN_CLASS_NAME: default_css_js_1.OBJECTFIT_CONTAIN_CLASS_NAME,
    InnerOffthreadVideo: OffthreadVideo_js_1.InnerOffthreadVideo,
    useBasicMediaInTimeline: use_media_in_timeline_js_1.useBasicMediaInTimeline,
    getInputPropsOverride: input_props_override_js_1.getInputPropsOverride,
    setInputPropsOverride: input_props_override_js_1.setInputPropsOverride,
    useVideoEnabled: use_media_enabled_js_1.useVideoEnabled,
    useAudioEnabled: use_media_enabled_js_1.useAudioEnabled,
    useIsPlayerBuffering: buffering_js_1.useIsPlayerBuffering,
    TimelinePosition,
    DelayRenderContextType: use_delay_render_js_1.DelayRenderContextType,
    TimelineContext: TimelineContext_js_1.TimelineContext,
    RenderAssetManagerProvider: RenderAssetManager_js_1.RenderAssetManagerProvider,
};
