"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.makeDefaultPreviewCSS = exports.OBJECTFIT_CONTAIN_CLASS_NAME = exports.injectCSS = void 0;
const injected = {};
const injectCSS = (css) => {
    // Skip in node
    if (typeof document === 'undefined') {
        return () => { };
    }
    if (injected[css]) {
        return () => { };
    }
    const head = document.head || document.getElementsByTagName('head')[0];
    const style = document.createElement('style');
    style.appendChild(document.createTextNode(css));
    head.prepend(style);
    injected[css] = style;
    return () => {
        const styleElement = injected[css];
        if (styleElement) {
            if (styleElement.parentNode) {
                styleElement.parentNode.removeChild(styleElement);
            }
            delete injected[css];
        }
    };
};
exports.injectCSS = injectCSS;
// make object-fit: contain low priority, so it can be overridden by another class name
exports.OBJECTFIT_CONTAIN_CLASS_NAME = '__remotion_objectfitcontain';
const makeDefaultPreviewCSS = (scope, backgroundColor) => {
    if (!scope) {
        return `
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
	    background-color: ${backgroundColor};
    }
    .${exports.OBJECTFIT_CONTAIN_CLASS_NAME} {
      object-fit: contain;
    }
    `;
    }
    return `
    ${scope} * {
      box-sizing: border-box;
    }
    ${scope} *:-webkit-full-screen {
      width: 100%;
      height: 100%;
    }
    ${scope} .${exports.OBJECTFIT_CONTAIN_CLASS_NAME} {
      object-fit: contain;
    }
  `;
};
exports.makeDefaultPreviewCSS = makeDefaultPreviewCSS;
