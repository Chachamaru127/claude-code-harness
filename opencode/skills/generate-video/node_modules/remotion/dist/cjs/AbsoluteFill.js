"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AbsoluteFill = void 0;
const jsx_runtime_1 = require("react/jsx-runtime");
const react_1 = require("react");
const hasTailwindClassName = ({ className, classPrefix, type, }) => {
    if (!className) {
        return false;
    }
    if (type === 'exact') {
        const split = className.split(' ');
        return classPrefix.some((token) => {
            return split.some((part) => {
                return (part.trim() === token ||
                    part.trim().endsWith(`:${token}`) ||
                    part.trim().endsWith(`!${token}`));
            });
        });
    }
    return classPrefix.some((prefix) => {
        return (className.startsWith(prefix) ||
            className.includes(` ${prefix}`) ||
            className.includes(`!${prefix}`) ||
            className.includes(`:${prefix}`));
    });
};
const AbsoluteFillRefForwarding = (props, ref) => {
    const { style, ...other } = props;
    const actualStyle = (0, react_1.useMemo)(() => {
        // Make TailwindCSS classes get accepted
        return {
            position: 'absolute',
            top: hasTailwindClassName({
                className: other.className,
                classPrefix: ['top-', 'inset-'],
                type: 'prefix',
            })
                ? undefined
                : 0,
            left: hasTailwindClassName({
                className: other.className,
                classPrefix: ['left-', 'inset-'],
                type: 'prefix',
            })
                ? undefined
                : 0,
            right: hasTailwindClassName({
                className: other.className,
                classPrefix: ['right-', 'inset-'],
                type: 'prefix',
            })
                ? undefined
                : 0,
            bottom: hasTailwindClassName({
                className: other.className,
                classPrefix: ['bottom-', 'inset-'],
                type: 'prefix',
            })
                ? undefined
                : 0,
            width: hasTailwindClassName({
                className: other.className,
                classPrefix: ['w-'],
                type: 'prefix',
            })
                ? undefined
                : '100%',
            height: hasTailwindClassName({
                className: other.className,
                classPrefix: ['h-'],
                type: 'prefix',
            })
                ? undefined
                : '100%',
            display: hasTailwindClassName({
                className: other.className,
                classPrefix: [
                    'block',
                    'inline-block',
                    'inline',
                    'flex',
                    'inline-flex',
                    'flow-root',
                    'grid',
                    'inline-grid',
                    'contents',
                    'list-item',
                    'hidden',
                ],
                type: 'exact',
            })
                ? undefined
                : 'flex',
            flexDirection: hasTailwindClassName({
                className: other.className,
                classPrefix: [
                    'flex-row',
                    'flex-col',
                    'flex-row-reverse',
                    'flex-col-reverse',
                ],
                type: 'exact',
            })
                ? undefined
                : 'column',
            ...style,
        };
    }, [other.className, style]);
    return (0, jsx_runtime_1.jsx)("div", { ref: ref, style: actualStyle, ...other });
};
/*
 * @description A helper component which renders an absolutely positioned <div> element with full width, height, and flex display suited for content layering.
 * @see [Documentation](https://remotion.dev/docs/absolute-fill)
 */
exports.AbsoluteFill = (0, react_1.forwardRef)(AbsoluteFillRefForwarding);
