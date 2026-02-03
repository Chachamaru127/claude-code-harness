"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CompositionManagerProvider = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const CompositionManager_1 = require("./CompositionManager");
const CompositionManagerContext_1 = require("./CompositionManagerContext");
const CompositionManagerProvider = ({ children, onlyRenderComposition, currentCompositionMetadata, initialCompositions, initialCanvasContent, }) => {
    const [folders, setFolders] = (0, react_1.useState)([]);
    const [canvasContent, setCanvasContent] = (0, react_1.useState)(initialCanvasContent);
    const [compositions, setCompositions] = (0, react_1.useState)(initialCompositions);
    // CompositionManagerProvider state
    const currentcompositionsRef = (0, react_1.useRef)(compositions);
    const updateCompositions = (0, react_1.useCallback)((updateComps) => {
        setCompositions((comps) => {
            const updated = updateComps(comps);
            currentcompositionsRef.current = updated;
            return updated;
        });
    }, []);
    const registerComposition = (0, react_1.useCallback)((comp) => {
        updateCompositions((comps) => {
            if (comps.find((c) => c.id === comp.id)) {
                throw new Error(`Multiple composition with id ${comp.id} are registered.`);
            }
            const value = [...comps, comp]
                .slice()
                .sort((a, b) => a.nonce - b.nonce);
            return value;
        });
    }, [updateCompositions]);
    const unregisterComposition = (0, react_1.useCallback)((id) => {
        setCompositions((comps) => {
            return comps.filter((c) => c.id !== id);
        });
    }, []);
    const registerFolder = (0, react_1.useCallback)((name, parent) => {
        setFolders((prevFolders) => {
            return [
                ...prevFolders,
                {
                    name,
                    parent,
                },
            ];
        });
    }, []);
    const unregisterFolder = (0, react_1.useCallback)((name, parent) => {
        setFolders((prevFolders) => {
            return prevFolders.filter((p) => !(p.name === name && p.parent === parent));
        });
    }, []);
    (0, react_1.useImperativeHandle)(CompositionManager_1.compositionsRef, () => {
        return {
            getCompositions: () => currentcompositionsRef.current,
        };
    }, []);
    const updateCompositionDefaultProps = (0, react_1.useCallback)((id, newDefaultProps) => {
        setCompositions((comps) => {
            const updated = comps.map((c) => {
                if (c.id === id) {
                    return {
                        ...c,
                        defaultProps: newDefaultProps,
                    };
                }
                return c;
            });
            return updated;
        });
    }, []);
    const compositionManagerSetters = (0, react_1.useMemo)(() => {
        return {
            registerComposition,
            unregisterComposition,
            registerFolder,
            unregisterFolder,
            setCanvasContent,
            updateCompositionDefaultProps,
            onlyRenderComposition,
        };
    }, [
        registerComposition,
        registerFolder,
        unregisterComposition,
        unregisterFolder,
        updateCompositionDefaultProps,
        onlyRenderComposition,
    ]);
    const compositionManagerContextValue = (0, react_1.useMemo)(() => {
        return {
            compositions,
            folders,
            currentCompositionMetadata,
            canvasContent,
        };
    }, [compositions, folders, currentCompositionMetadata, canvasContent]);
    return ((0, jsx_runtime_1.jsx)(CompositionManagerContext_1.CompositionManager.Provider, { value: compositionManagerContextValue, children: (0, jsx_runtime_1.jsx)(CompositionManagerContext_1.CompositionSetters.Provider, { value: compositionManagerSetters, children: children }) }));
};
exports.CompositionManagerProvider = CompositionManagerProvider;
