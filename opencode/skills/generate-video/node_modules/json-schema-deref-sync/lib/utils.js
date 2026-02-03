const path = require('path')
const validUrl = require('valid-url')
const isValidPath = require('is-valid-path')

const isWindows = process.platform === 'win32'

/**
 * Gets the ref value of a search result from prop-search or ref object
 * @param ref The search result object from prop-search
 * @returns {*} The value of $ref or undefined if not present in search object
 * @private
 */
function getRefValue (ref) {
  const thing = ref ? (ref.value ? ref.value : ref) : null
  if (thing && thing.$ref && typeof thing.$ref === 'string') {
    return thing.$ref
  }
}
exports.getRefValue = getRefValue

/**
 * Gets the type of $ref from search result object.
 * @param ref The search result object from prop-search or a ref object
 * @returns {string}  `web` if it's a web url.
 *                    `file` if it's a file path.
 *                    `local` if it's a link to local schema.
 *                    undefined otherwise
 * @private
 */
function getRefType (ref) {
  const val = getRefValue(ref)
  if (val) {
    if ((val.charAt(0) === '#')) {
      return 'local'
    }
    
    if (validUrl.isWebUri(val)) {
      return 'web'
    }

    return 'file'
  }
}
exports.getRefType = getRefType

/**
 * Determines if object is a $ref object. That is { $ref: <something> }
 * @param thing object to test
 * @returns {boolean} true if passes the test. false otherwise.
 * @private
 */
function isRefObject (thing) {
  if (thing && typeof thing === 'object' && !Array.isArray(thing)) {
    const keys = Object.keys(thing)
    return keys.length === 1 && keys[0] === '$ref' && typeof thing.$ref === 'string'
  }
  return false
}
exports.isRefObject = isRefObject

/**
 * Gets the value at the ref path within schema
 * @param schema the (root) json schema to search
 * @param refPath string ref path to get within the schema. Ex. `#/definitions/id`
 * @returns {*} Returns the value at the path location or undefined if not found within the given schema
 * @private
 */
function getRefPathValue (schema, refPath) {
  let rpath = refPath
  const hashIndex = refPath.indexOf('#')
  if (hashIndex >= 0) {
    rpath = refPath.substring(hashIndex)
    if (rpath.length > 1) {
      rpath = refPath.substring(1)
    } else {
      rpath = ''
    }
  }

  // Walk through each /-separated path component, and get
  // the value for that key (ignoring empty keys)
  const keys = rpath.split('/').filter(k => !!k)
  return keys.reduce(function (value, key) {
    return value[key]
  }, schema)
}
exports.getRefPathValue = getRefPathValue

function getRefFilePath (refPath) {
  let filePath = refPath
  const hashIndex = filePath.indexOf('#')
  if (hashIndex > 0) {
    filePath = refPath.substring(0, hashIndex)
  }

  return filePath
}
exports.getRefFilePath = getRefFilePath

// Regex to split a windows path into three parts: [*, device, slash,
// tail] windows-only
const splitDeviceRe = /^([a-zA-Z]:|[\\\/]{2}[^\\\/]+[\\\/]+[^\\\/]+)?([\\\/])?([\s\S]*?)$/

function win32StatPath (path) {
  const result = splitDeviceRe.exec(path)
  const device = result[1] || ''
  const isUnc = !!device && device[1] !== ':'

  return {
    device: device,
    isUnc: isUnc,
    isAbsolute: isUnc || !!result[2], // UNC paths are always absolute
    tail: result[3]
  }
}

exports.isAbsolute = typeof path.isAbsolute === 'function' ? path.isAbsolute : function utilIsAbsolute (path) {
  if (isWindows) {
    return win32StatPath(path).isAbsolute
  }
  return !!path && path[0] === '/'
}
