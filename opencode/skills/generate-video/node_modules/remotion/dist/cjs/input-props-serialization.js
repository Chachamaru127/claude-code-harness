"use strict";
// Must keep this file in sync with the one in packages/lambda/src/shared/serialize-props.ts!
Object.defineProperty(exports, "__esModule", { value: true });
exports.serializeThenDeserializeInStudio = exports.serializeThenDeserialize = exports.deserializeJSONWithSpecialTypes = exports.serializeJSONWithSpecialTypes = exports.FILE_TOKEN = exports.DATE_TOKEN = void 0;
const get_remotion_environment_js_1 = require("./get-remotion-environment.js");
exports.DATE_TOKEN = 'remotion-date:';
exports.FILE_TOKEN = 'remotion-file:';
const serializeJSONWithSpecialTypes = ({ data, indent, staticBase, }) => {
    let customDateUsed = false;
    let customFileUsed = false;
    let mapUsed = false;
    let setUsed = false;
    try {
        const serializedString = JSON.stringify(data, function (key, value) {
            const item = this[key];
            if (item instanceof Date) {
                customDateUsed = true;
                return `${exports.DATE_TOKEN}${item.toISOString()}`;
            }
            if (item instanceof Map) {
                mapUsed = true;
                return value;
            }
            if (item instanceof Set) {
                setUsed = true;
                return value;
            }
            if (typeof item === 'string' &&
                staticBase !== null &&
                item.startsWith(staticBase)) {
                customFileUsed = true;
                return `${exports.FILE_TOKEN}${item.replace(staticBase + '/', '')}`;
            }
            return value;
        }, indent);
        return { serializedString, customDateUsed, customFileUsed, mapUsed, setUsed };
    }
    catch (err) {
        throw new Error('Could not serialize the passed input props to JSON: ' +
            err.message);
    }
};
exports.serializeJSONWithSpecialTypes = serializeJSONWithSpecialTypes;
const deserializeJSONWithSpecialTypes = (data) => {
    return JSON.parse(data, (_, value) => {
        if (typeof value === 'string' && value.startsWith(exports.DATE_TOKEN)) {
            return new Date(value.replace(exports.DATE_TOKEN, ''));
        }
        if (typeof value === 'string' && value.startsWith(exports.FILE_TOKEN)) {
            return `${window.remotion_staticBase}/${value.replace(exports.FILE_TOKEN, '')}`;
        }
        return value;
    });
};
exports.deserializeJSONWithSpecialTypes = deserializeJSONWithSpecialTypes;
const serializeThenDeserialize = (props) => {
    return (0, exports.deserializeJSONWithSpecialTypes)((0, exports.serializeJSONWithSpecialTypes)({
        data: props,
        indent: 2,
        staticBase: window.remotion_staticBase,
    }).serializedString);
};
exports.serializeThenDeserialize = serializeThenDeserialize;
const serializeThenDeserializeInStudio = (props) => {
    // Serializing once in the Studio, to catch potential serialization errors before
    // you only get them during rendering
    if ((0, get_remotion_environment_js_1.getRemotionEnvironment)().isStudio) {
        return (0, exports.serializeThenDeserialize)(props);
    }
    return props;
};
exports.serializeThenDeserializeInStudio = serializeThenDeserializeInStudio;
