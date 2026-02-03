# memory-cache [![Build Status](https://travis-ci.org/ptarjan/node-cache.svg?branch=master)](https://travis-ci.org/ptarjan/node-cache)

A simple in-memory cache for node.js

## Installation

    npm install memory-cache --save

## Usage

```javascript
var cache = require('memory-cache');

// now just use the cache

cache.put('foo', 'bar');
console.log(cache.get('foo'));

// that wasn't too interesting, here's the good part

cache.put('houdini', 'disappear', 100, function(key, value) {
    console.log(key + ' did ' + value);
}); // Time in ms

console.log('Houdini will now ' + cache.get('houdini'));

setTimeout(function() {
    console.log('Houdini is ' + cache.get('houdini'));
}, 200);


// create new cache instance
var newCache = new cache.Cache();

newCache.put('foo', 'newbaz');

setTimeout(function() {
  console.log('foo in old cache is ' + cache.get('foo'));
  console.log('foo in new cache is ' + newCache.get('foo'));
}, 200);
```

which should print

    bar
    Houdini will now disappear
    houdini did disappear
    Houdini is null
    foo in old cache is baz
    foo in new cache is newbaz

## API

### put = function(key, value, time, timeoutCallback)

* Simply stores a value
* If time isn't passed in, it is stored forever
* Will actually remove the value in the specified time in ms (via `setTimeout`)
* timeoutCallback is optional function fired after entry has expired with key and value passed (`function(key, value) {}`)
* Returns the cached value

### get = function(key)

* Retrieves a value for a given key
* If value isn't cached, returns `null`

### del = function(key)

* Deletes a key, returns a boolean specifying whether or not the key was deleted

### clear = function()

* Deletes all keys

### size = function()

* Returns the current number of entries in the cache

### memsize = function()

* Returns the number of entries taking up space in the cache
* Will usually `== size()` unless a `setTimeout` removal went wrong

### debug = function(bool)

* Turns on or off debugging

### hits = function()

* Returns the number of cache hits (only monitored in debug mode)

### misses = function()

* Returns the number of cache misses (only monitored in debug mode)

### keys = function()

* Returns all the cache keys

### exportJson = function()

* Returns a JSON string representing all the cache data
* Any timeoutCallbacks will be ignored

### importJson = function(json: string, options: { skipDuplicates: boolean })

* Merges all the data from a previous call to `export` into the cache
* Any existing entries before an `import` will remain in the cache
* Any duplicate keys will be overwritten, unless `skipDuplicates` is `true`
* Any entries that would have expired since being exported will expire upon being imported (but their callbacks will not be invoked)
* Available `options`:
  * `skipDuplicates`: If `true`, any duplicate keys will be ignored when importing them. Defaults to `false`.
* Returns the new size of the cache

### Cache = function()

* Cache constructor
* note that `require('cache')` would return the default instance of Cache
* while `require('cache').Cache` is the actual class

## Note on Patches/Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Send me a pull request.
