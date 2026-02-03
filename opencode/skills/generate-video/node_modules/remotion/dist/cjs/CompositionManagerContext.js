"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CompositionSetters = exports.CompositionManager = void 0;
const react_1 = require("react");
exports.CompositionManager = (0, react_1.createContext)({
    compositions: [],
    folders: [],
    currentCompositionMetadata: null,
    canvasContent: null,
});
exports.CompositionSetters = (0, react_1.createContext)({
    registerComposition: () => undefined,
    unregisterComposition: () => undefined,
    registerFolder: () => undefined,
    unregisterFolder: () => undefined,
    setCanvasContent: () => undefined,
    updateCompositionDefaultProps: () => undefined,
    onlyRenderComposition: null,
});
