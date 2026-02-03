"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RenderAssetManagerProvider = exports.RenderAssetManager = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const validate_artifact_js_1 = require("./validation/validate-artifact.js");
exports.RenderAssetManager = (0, react_1.createContext)({
    // Must be undefined, otherwise error in Player
    registerRenderAsset: () => undefined,
    unregisterRenderAsset: () => undefined,
    renderAssets: [],
});
const RenderAssetManagerProvider = ({ children, collectAssets }) => {
    const [renderAssets, setRenderAssets] = (0, react_1.useState)([]);
    const renderAssetsRef = (0, react_1.useRef)([]);
    const registerRenderAsset = (0, react_1.useCallback)((renderAsset) => {
        (0, validate_artifact_js_1.validateRenderAsset)(renderAsset);
        renderAssetsRef.current = [...renderAssetsRef.current, renderAsset];
        setRenderAssets(renderAssetsRef.current);
    }, []);
    if (collectAssets) {
        // eslint-disable-next-line react-hooks/rules-of-hooks
        (0, react_1.useImperativeHandle)(collectAssets, () => {
            return {
                collectAssets: () => {
                    const assets = renderAssetsRef.current;
                    renderAssetsRef.current = [];
                    setRenderAssets([]);
                    return assets;
                },
            };
        }, []);
    }
    const unregisterRenderAsset = (0, react_1.useCallback)((id) => {
        renderAssetsRef.current = renderAssetsRef.current.filter((a) => a.id !== id);
        setRenderAssets(renderAssetsRef.current);
    }, []);
    (0, react_1.useLayoutEffect)(() => {
        if (typeof window !== 'undefined') {
            window.remotion_collectAssets = () => {
                const assets = renderAssetsRef.current;
                renderAssetsRef.current = [];
                setRenderAssets([]);
                return assets;
            };
        }
    }, []);
    const contextValue = (0, react_1.useMemo)(() => {
        return {
            registerRenderAsset,
            unregisterRenderAsset,
            renderAssets,
        };
    }, [renderAssets, registerRenderAsset, unregisterRenderAsset]);
    return ((0, jsx_runtime_1.jsx)(exports.RenderAssetManager.Provider, { value: contextValue, children: children }));
};
exports.RenderAssetManagerProvider = RenderAssetManagerProvider;
