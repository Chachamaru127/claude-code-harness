# json-schema-deref-sync

[![npm version](https://img.shields.io/npm/v/json-schema-deref-sync.svg?style=flat-square)](https://www.npmjs.com/package/json-schema-deref-sync)
[![build status](https://img.shields.io/travis/bojand/json-schema-deref-sync/master.svg?style=flat-square)](https://travis-ci.org/bojand/json-schema-deref-sync)
[![JavaScript Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg?style=flat-square)](https://standardjs.com)
[![License](https://img.shields.io/github/license/bojand/json-schema-deref-sync.svg?style=flat-square)](https://raw.githubusercontent.com/bojand/json-schema-deref-sync/master/LICENSE)

Dereference JSON pointers in a JSON schemas with their true resolved values.
Basically a lighter, synchronous version of [json-schema-deref](https://github.com/bojand/json-schema-deref) but omits web references.

## Installation

`npm install json-schema-deref-sync`

## Overview

Let's say you have the following JSON Schema:

```json
{
  "description": "Just some JSON schema.",
  "title": "Basic Widget",
  "type": "object",
  "definitions": {
    "id": {
      "description": "unique identifier",
      "type": "string",
      "minLength": 1,
      "readOnly": true
    }
  },
  "properties": {
    "id": {
      "$ref": "#/definitions/id"
    },
    "bar": {
      "$ref": "bar.json"
    }
  }
}
```

Sometimes you just want that schema to be fully expanded, with `$ref`'s being their (true) resolved values:

```json
{
  "description": "Just some JSON schema.",
  "title": "Basic Widget",
  "type": "object",
  "definitions": {
    "id": {
      "description": "unique identifier",
      "type": "string",
      "minLength": 1,
      "readOnly": true
    }
  },
  "properties": {
    "id": {
      "description": "unique identifier",
      "type": "string",
      "minLength": 1,
      "readOnly": true
    },
    "bar": {
      "description": "bar property",
      "type": "boolean"
    }
  }
}
```

This utility lets you do that:


```js
var deref = require('json-schema-deref-sync');
var myschema = require('schema.json');

var fullSchema = deref(myschema);
```

## API Reference

<a name="deref"></a>

## deref(schema, options) ⇒ <code>Object</code> \| <code>Error</code>
Derefs <code>$ref</code>'s in JSON Schema to actual resolved values. Supports local, and file refs.

**Kind**: global function  
**Returns**: <code>Object</code> \| <code>Error</code> - the deref schema oran instance of <code>Error</code> if error.  

| Param | Type | Description |
| --- | --- | --- |
| schema | <code>Object</code> | The JSON schema |
| options | <code>Object</code> | options |
| options.baseFolder | <code>String</code> | the base folder to get relative path files from. Default is <code>process.cwd()</code> |
| options.failOnMissing | <code>Boolean</code> | By default missing / unresolved refs will be left as is with their ref value intact.                                        If set to <code>true</code> we will error out on first missing ref that we cannot                                        resolve. Default: <code>false</code>. |
| options.mergeAdditionalProperties | <code>Boolean</code> | By default properties in a object with $ref will be removed in the output.                                                    If set to <code>true</code> they will be added/overwrite the output. This will use lodash's merge function.                                                    Default: <code>false</code>. |
| options.removeIds | <code>Boolean</code> | By default <code>$id</code> fields will get copied when dereferencing.                                    If set to <code>true</code> they will be removed.  Merged properties will not get removed.                                    Default: <code>false</code>. |
| options.loaders | <code>Object</code> | A hash mapping reference types (e.g., 'file') to loader functions. |

