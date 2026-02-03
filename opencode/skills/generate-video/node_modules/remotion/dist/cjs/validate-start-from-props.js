"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveTrimProps = exports.validateMediaTrimProps = exports.validateTrimProps = exports.validateStartFromProps = void 0;
const validateStartFromProps = (startFrom, endAt) => {
    if (typeof startFrom !== 'undefined') {
        if (typeof startFrom !== 'number') {
            throw new TypeError(`type of startFrom prop must be a number, instead got type ${typeof startFrom}.`);
        }
        if (isNaN(startFrom) || startFrom === Infinity) {
            throw new TypeError('startFrom prop can not be NaN or Infinity.');
        }
        if (startFrom < 0) {
            throw new TypeError(`startFrom must be greater than equal to 0 instead got ${startFrom}.`);
        }
    }
    if (typeof endAt !== 'undefined') {
        if (typeof endAt !== 'number') {
            throw new TypeError(`type of endAt prop must be a number, instead got type ${typeof endAt}.`);
        }
        if (isNaN(endAt)) {
            throw new TypeError('endAt prop can not be NaN.');
        }
        if (endAt <= 0) {
            throw new TypeError(`endAt must be a positive number, instead got ${endAt}.`);
        }
    }
    if (endAt < startFrom) {
        throw new TypeError('endAt prop must be greater than startFrom prop.');
    }
};
exports.validateStartFromProps = validateStartFromProps;
const validateTrimProps = (trimBefore, trimAfter) => {
    if (typeof trimBefore !== 'undefined') {
        if (typeof trimBefore !== 'number') {
            throw new TypeError(`type of trimBefore prop must be a number, instead got type ${typeof trimBefore}.`);
        }
        if (isNaN(trimBefore) || trimBefore === Infinity) {
            throw new TypeError('trimBefore prop can not be NaN or Infinity.');
        }
        if (trimBefore < 0) {
            throw new TypeError(`trimBefore must be greater than equal to 0 instead got ${trimBefore}.`);
        }
    }
    if (typeof trimAfter !== 'undefined') {
        if (typeof trimAfter !== 'number') {
            throw new TypeError(`type of trimAfter prop must be a number, instead got type ${typeof trimAfter}.`);
        }
        if (isNaN(trimAfter)) {
            throw new TypeError('trimAfter prop can not be NaN.');
        }
        if (trimAfter <= 0) {
            throw new TypeError(`trimAfter must be a positive number, instead got ${trimAfter}.`);
        }
    }
    if (trimAfter <= trimBefore) {
        throw new TypeError('trimAfter prop must be greater than trimBefore prop.');
    }
};
exports.validateTrimProps = validateTrimProps;
const validateMediaTrimProps = ({ startFrom, endAt, trimBefore, trimAfter, }) => {
    // Check for conflicting props
    if (typeof startFrom !== 'undefined' && typeof trimBefore !== 'undefined') {
        throw new TypeError('Cannot use both startFrom and trimBefore props. Use trimBefore instead as startFrom is deprecated.');
    }
    if (typeof endAt !== 'undefined' && typeof trimAfter !== 'undefined') {
        throw new TypeError('Cannot use both endAt and trimAfter props. Use trimAfter instead as endAt is deprecated.');
    }
    // Validate using the appropriate validation function
    const hasNewProps = typeof trimBefore !== 'undefined' || typeof trimAfter !== 'undefined';
    const hasOldProps = typeof startFrom !== 'undefined' || typeof endAt !== 'undefined';
    if (hasNewProps) {
        (0, exports.validateTrimProps)(trimBefore, trimAfter);
    }
    else if (hasOldProps) {
        (0, exports.validateStartFromProps)(startFrom, endAt);
    }
};
exports.validateMediaTrimProps = validateMediaTrimProps;
const resolveTrimProps = ({ startFrom, endAt, trimBefore, trimAfter, }) => {
    var _a, _b;
    // Use new props if available, otherwise fall back to old props
    const trimBeforeValue = (_a = trimBefore !== null && trimBefore !== void 0 ? trimBefore : startFrom) !== null && _a !== void 0 ? _a : undefined;
    const trimAfterValue = (_b = trimAfter !== null && trimAfter !== void 0 ? trimAfter : endAt) !== null && _b !== void 0 ? _b : undefined;
    return { trimBeforeValue, trimAfterValue };
};
exports.resolveTrimProps = resolveTrimProps;
