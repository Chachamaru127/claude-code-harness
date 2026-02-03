const path = require('path')
const _ = require('lodash')
const clone = require('clone')
const traverse = require('traverse')
const DAG = require('dag-map')
const md5 = require('md5')
const utils = require('./utils')
const fileLoader = require('./loaders/file')

const defaults = {
  baseFolder: process.cwd()
}

let cache = {}

const loaders = {
  file: fileLoader
}

function getLoader (refType, options) {
  return _.get(options, `loaders.${refType}`, loaders[refType]);
}

/**
 * Returns the reference schema that refVal points to.
 * If the ref val points to a ref within a file, the file is loaded and fully derefed, before we get the
 * pointing property. Derefed files are cached.
 *
 * @param refVal
 * @param refType
 * @param parent
 * @param options
 * @param state
 * @private
 */
function getRefSchema (refVal, refType, parent, options, state) {
  const loader = getLoader(refType, options)
  if (refType && loader) {
    let newVal
    let oldBasePath
    let loaderValue
    let filePath
    let fullRefFilePath

    if (refType === 'file') {
      filePath = utils.getRefFilePath(refVal)
      fullRefFilePath = utils.isAbsolute(filePath) ? filePath : path.resolve(state.cwd, filePath)

      if (cache[fullRefFilePath]) {
        loaderValue = cache[fullRefFilePath]
      }
    }

    if (!loaderValue) {
      loaderValue = loader(refVal, options)
      if (loaderValue) {
        // adjust base folder if needed so that we can handle paths in nested folders
        if (refType === 'file') {
          let dirname = path.dirname(filePath)
          if (dirname === '.') {
            dirname = ''
          }

          if (dirname) {
            oldBasePath = state.cwd
            const newBasePath = path.resolve(state.cwd, dirname)
            options.baseFolder = state.cwd = newBasePath
          }
        }

        loaderValue = derefSchema(loaderValue, options, state)

        // reset
        if (oldBasePath) {
          options.baseFolder = state.cwd = oldBasePath
        }
      }
    }

    if (loaderValue) {
      if (refType === 'file' && fullRefFilePath && !cache[fullRefFilePath]) {
        cache[fullRefFilePath] = loaderValue
      }

      if (refVal.indexOf('#') >= 0) {
        const refPaths = refVal.split('#')
        const refPath = refPaths[1]
        const refNewVal = utils.getRefPathValue(loaderValue, refPath)
        if (refNewVal) {
          newVal = refNewVal
        }
      } else {
        newVal = loaderValue
      }
    }

    return newVal
  } else if (refType === 'local') {
    return utils.getRefPathValue(parent, refVal)
  }
}

/**
 * Add to state history
 * @param {Object} state the state
 * @param {String} type ref type
 * @param {String} value ref value
 * @private
 */
function addToHistory (state, type, value) {
  let dest

  if (type === 'file') {
    dest = utils.getRefFilePath(value)
  } else {
    if (value === '#') {
      return false
    }
    dest = state.current.concat(`:${value}`)
  }

  if (dest) {
    dest = dest.toLowerCase()
    if (state.history.indexOf(dest) >= 0) {
      return false
    }

    state.history.push(dest)
  }
  return true
}

/**
 * Set the current into state
 * @param {Object} state the state
 * @param {String} type ref type
 * @param {String} value ref value
 * @private
 */
function setCurrent (state, type, value) {
  let dest
  if (type === 'file') {
    dest = utils.getRefFilePath(value)
  }

  if (dest) {
    state.current = dest
  }
}

/**
 * Check the schema for local circular refs using DAG
 * @param {Object} schema the schema
 * @return {Error|undefined} <code>Error</code> if circular ref, <code>undefined</code> otherwise if OK
 * @private
 */
function checkLocalCircular (schema) {
  const dag = new DAG()
  const locals = traverse(schema).reduce(function (acc, node) {
    if (!_.isNull(node) && !_.isUndefined(null) && typeof node.$ref === 'string') {
      const refType = utils.getRefType(node)
      if (refType === 'local') {
        const value = utils.getRefValue(node)
        if (value) {
          const path = this.path.join('/')
          acc.push({
            from: path,
            to: value
          })
        }
      }
    }
    return acc
  }, [])

  if (!locals || !locals.length) {
    return
  }

  if (_.some(locals, elem => elem.to === '#')) {
    return new Error('Circular self reference')
  }

  const check = _.find(locals, elem => {
    const fromEdge = elem.from.concat('/')
    const dest = elem.to.substring(2).concat('/')
    try {
      dag.addEdge(fromEdge, dest)
    } catch (e) {
      return elem
    }

    if (fromEdge.indexOf(dest) === 0) {
      return elem
    }
  })

  if (check) {
    return new Error(`Circular self reference from ${check.from} to ${check.to}`)
  }
}

/**
 * Derefs $ref types in a schema
 * @param schema
 * @param options
 * @param state
 * @param type
 * @private
 */
function derefSchema (schema, options, state) {
  const check = checkLocalCircular(schema)
  if (check instanceof Error) {
    return check
  }

  if (state.circular) {
    return new Error(`circular references found: ${state.circularRefs.toString()}`)
  } else if (state.error) {
    return state.error
  }

  return traverse(schema).forEach(function (node) {
    if (!_.isNull(node) && !_.isUndefined(null) && typeof node.$ref === 'string') {
      const refType = utils.getRefType(node)
      const refVal = utils.getRefValue(node)

      const addOk = addToHistory(state, refType, refVal)
      if (!addOk) {
        state.circular = true
        state.circularRefs.push(refVal)
        state.error = new Error(`circular references found: ${state.circularRefs.toString()}`)
        this.update(node, true)
      } else {
        setCurrent(state, refType, refVal)
        let newValue = getRefSchema(refVal, refType, schema, options, state)
        state.history.pop()
        if (newValue === undefined) {
          if (state.missing.indexOf(refVal) === -1) {
            state.missing.push(refVal)
          }
          if (options.failOnMissing) {
            state.error = new Error(`Missing $ref: ${refVal}`)
          }
          this.update(node, options.failOnMissing)
        } else {
          if (options.removeIds && newValue.hasOwnProperty('$id')) {
            delete newValue.$id
          }
          if (options.mergeAdditionalProperties) {
            delete node.$ref
            newValue = _.merge(newValue, node)
          }
          this.update(newValue)
          if (state.missing.indexOf(refVal) !== -1) {
            state.missing.splice(state.missing.indexOf(refVal), 1)
          }
        }
      }
    }
  })
}

/**
 * Derefs <code>$ref</code>'s in JSON Schema to actual resolved values. Supports local, and file refs.
 * @param {Object} schema - The JSON schema
 * @param {Object} options - options
 * @param {String} options.baseFolder - the base folder to get relative path files from. Default is <code>process.cwd()</code>
 * @param {Boolean} options.failOnMissing - By default missing / unresolved refs will be left as is with their ref value intact.
 *                                        If set to <code>true</code> we will error out on first missing ref that we cannot
 *                                        resolve. Default: <code>false</code>.
 * @param {Boolean} options.mergeAdditionalProperties - By default properties in a object with $ref will be removed in the output.
 *                                                    If set to <code>true</code> they will be added/overwrite the output. This will use lodash's merge function.
 *                                                    Default: <code>false</code>.
 * @param {Boolean} options.removeIds - By default <code>$id</code> fields will get copied when dereferencing.
 *                                    If set to <code>true</code> they will be removed. Merged properties will not get removed.
 *                                    Default: <code>false</code>.
 * @param {Object} options.loaders - A hash mapping reference types (e.g., 'file') to loader functions.
 * @return {Object|Error} the deref schema oran instance of <code>Error</code> if error.
 */
function deref (schema, options) {
  options = _.defaults(options, defaults)

  const bf = options.baseFolder
  let cwd = bf
  if (!utils.isAbsolute(bf)) {
    cwd = path.resolve(process.cwd(), bf)
  }

  const state = {
    graph: new DAG(),
    circular: false,
    circularRefs: [],
    cwd: cwd,
    missing: [],
    history: []
  }

  try {
    const str = JSON.stringify(schema)
    state.current = md5(str)
  } catch (e) {
    return e
  }

  const baseSchema = clone(schema)

  cache = {}

  let ret = derefSchema(baseSchema, options, state)
  if (ret instanceof Error === false && state.error) {
    return state.error
  }
  return ret
}

module.exports = deref
