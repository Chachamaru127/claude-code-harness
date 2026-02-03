/* global describe, it, before, beforeEach, afterEach */
'use strict';

var chai = require('chai'),
    expect = chai.expect,
    sinon = require('sinon'),
    sinonChai = require('sinon-chai'),
    Cache = require('./index').Cache,
    cache = new Cache(),
    clock;

chai.use(sinonChai);


describe('node-cache', function() {
  beforeEach(function() {
    clock = sinon.useFakeTimers();

    cache.clear();
  });

  afterEach(function() {
    clock.restore();
  });

  describe('put()', function() {
    before(function() {
      cache.debug(false);
    });

    it('should allow adding a new item to the cache', function() {
      expect(function() {
        cache.put('key', 'value');
      }).to.not.throw();
    });

    it('should allow adding a new item to the cache with a timeout', function() {
      expect(function() {
        cache.put('key', 'value', 100);
      }).to.not.throw();
    });

    it('should allow adding a new item to the cache with a timeout callback', function() {
      expect(function() {
        cache.put('key', 'value', 100, function() {});
      }).to.not.throw();
    });

    it('should throw an error given a non-numeric timeout', function() {
      expect(function() {
        cache.put('key', 'value', 'foo');
      }).to.throw();
    });

    it('should throw an error given a timeout of NaN', function() {
      expect(function() {
        cache.put('key', 'value', NaN);
      }).to.throw();
    });

    it('should throw an error given a timeout of 0', function() {
      expect(function() {
        cache.put('key', 'value', 0);
      }).to.throw();
    });

    it('should throw an error given a negative timeout', function() {
      expect(function() {
        cache.put('key', 'value', -100);
      }).to.throw();
    });

    it('should throw an error given a non-function timeout callback', function() {
      expect(function() {
        cache.put('key', 'value', 100, 'foo');
      }).to.throw();
    });

    it('should cause the timeout callback to fire once the cache item expires', function() {
      var spy = sinon.spy();
      cache.put('key', 'value', 1000, spy);
      clock.tick(999);
      expect(spy).to.not.have.been.called;
      clock.tick(1);
      expect(spy).to.have.been.calledOnce.and.calledWith('key', 'value');
    });

    it('should override the timeout callback on a new put() with a different timeout callback', function() {
      var spy1 = sinon.spy();
      var spy2 = sinon.spy();
      cache.put('key', 'value', 1000, spy1);
      clock.tick(999);
      cache.put('key', 'value', 1000, spy2)
      clock.tick(1001);
      expect(spy1).to.not.have.been.called;
      expect(spy2).to.have.been.calledOnce.and.calledWith('key', 'value');
    });

    it('should cancel the timeout callback on a new put() without a timeout callback', function() {
      var spy = sinon.spy();
      cache.put('key', 'value', 1000, spy);
      clock.tick(999);
      cache.put('key', 'value');
      clock.tick(1);
      expect(spy).to.not.have.been.called;
    });

    it('should return the cached value', function() {
      expect(cache.put('key', 'value')).to.equal('value');
    });
  });

  describe('del()', function() {
    before(function() {
      cache.debug(false);
    });

    it('should return false given a key for an empty cache', function() {
      expect(cache.del('miss')).to.be.false;
    });

    it('should return false given a key not in a non-empty cache', function() {
      cache.put('key', 'value');
      expect(cache.del('miss')).to.be.false;
    });

    it('should return true given a key in the cache', function() {
      cache.put('key', 'value');
      expect(cache.del('key')).to.be.true;
    });

    it('should remove the provided key from the cache', function() {
      cache.put('key', 'value');
      expect(cache.get('key')).to.equal('value');
      expect(cache.del('key')).to.be.true;
      expect(cache.get('key')).to.be.null;
    });

    it('should decrement the cache size by 1', function() {
      cache.put('key', 'value');
      expect(cache.size()).to.equal(1);
      expect(cache.del('key')).to.be.true;
      expect(cache.size()).to.equal(0);
    });

    it('should not remove other keys in the cache', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.get('key1')).to.equal('value1');
      expect(cache.get('key2')).to.equal('value2');
      expect(cache.get('key3')).to.equal('value3');
      cache.del('key1');
      expect(cache.get('key1')).to.be.null;
      expect(cache.get('key2')).to.equal('value2');
      expect(cache.get('key3')).to.equal('value3');
    });

    it('should only delete a key from the cache once even if called multiple times in a row', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.size()).to.equal(3);
      cache.del('key1');
      cache.del('key1');
      cache.del('key1');
      expect(cache.size()).to.equal(2);
    });

    it('should handle deleting keys which were previously deleted and then re-added to the cache', function() {
      cache.put('key', 'value');
      expect(cache.get('key')).to.equal('value');
      cache.del('key');
      expect(cache.get('key')).to.be.null;
      cache.put('key', 'value');
      expect(cache.get('key')).to.equal('value');
      cache.del('key');
      expect(cache.get('key')).to.be.null;
    });

    it('should return true given an non-expired key', function() {
      cache.put('key', 'value', 1000);
      clock.tick(999);
      expect(cache.del('key')).to.be.true;
    });

    it('should return false given an expired key', function() {
      cache.put('key', 'value', 1000);
      clock.tick(1000);
      expect(cache.del('key')).to.be.false;
    });

    it('should cancel the timeout callback for the deleted key', function() {
      var spy = sinon.spy();
      cache.put('key', 'value', 1000, spy);
      cache.del('key');
      clock.tick(1000);
      expect(spy).to.not.have.been.called;
    });

    it('should handle deletion of many items', function(done) {
      clock.restore();
      var num = 1000;
      for(var i = 0; i < num; i++){
        cache.put('key' + i, i, 1000);
      }
      expect(cache.size()).to.equal(num);
      setTimeout(function(){
        expect(cache.size()).to.equal(0);
        done();
      }, 1000);
    });
  });

  describe('clear()', function() {
    before(function() {
      cache.debug(false);
    });

    it('should have no effect given an empty cache', function() {
      expect(cache.size()).to.equal(0);
      cache.clear();
      expect(cache.size()).to.equal(0);
    });

    it('should remove all existing keys in the cache', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.size()).to.equal(3);
      cache.clear();
      expect(cache.size()).to.equal(0);
    });

    it('should remove the keys in the cache', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.get('key1')).to.equal('value1');
      expect(cache.get('key2')).to.equal('value2');
      expect(cache.get('key3')).to.equal('value3');
      cache.clear();
      expect(cache.get('key1')).to.be.null;
      expect(cache.get('key2')).to.be.null;
      expect(cache.get('key3')).to.be.null;
    });

    it('should reset the cache size to 0', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.size()).to.equal(3);
      cache.clear();
      expect(cache.size()).to.equal(0);
    });

    it('should reset the debug cache hits', function() {
      cache.debug(true);
      cache.put('key', 'value');
      cache.get('key');
      expect(cache.hits()).to.equal(1);
      cache.clear();
      expect(cache.hits()).to.equal(0);
    });

    it('should reset the debug cache misses', function() {
      cache.debug(true);
      cache.put('key', 'value');
      cache.get('miss1');
      expect(cache.misses()).to.equal(1);
      cache.clear();
      expect(cache.misses()).to.equal(0);
    });

    it('should cancel the timeout callbacks for all existing keys', function() {
      var spy1 = sinon.spy();
      var spy2 = sinon.spy();
      var spy3 = sinon.spy();
      cache.put('key1', 'value1', 1000, spy1);
      cache.put('key2', 'value2', 1000, spy2);
      cache.put('key3', 'value3', 1000, spy3);
      cache.clear();
      clock.tick(1000);
      expect(spy1).to.not.have.been.called;
      expect(spy2).to.not.have.been.called;
      expect(spy3).to.not.have.been.called;
    });
  });

  describe('get()', function() {
    before(function() {
      cache.debug(false);
    });

    it('should return null given a key for an empty cache', function() {
      expect(cache.get('miss')).to.be.null;
    });

    it('should return null given a key not in a non-empty cache', function() {
      cache.put('key', 'value');
      expect(cache.get('miss')).to.be.null;
    });

    it('should return the corresponding value of a key in the cache', function() {
      cache.put('key', 'value');
      expect(cache.get('key')).to.equal('value');
    });

    it('should return the latest corresponding value of a key in the cache', function() {
      cache.put('key', 'value1');
      cache.put('key', 'value2');
      cache.put('key', 'value3');
      expect(cache.get('key')).to.equal('value3');
    });

    it('should handle various types of cache keys', function() {
      var keys = [null, undefined, NaN, true, false, 0, 1, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, '', 'a', [], {}, [1, 'a', false], {a:1,b:'a',c:false}, function() {}];
      keys.forEach(function(key, index) {
        var value = 'value' + index;
        cache.put(key, value);
        expect(cache.get(key)).to.deep.equal(value);
      });
    });

    it('should handle various types of cache values', function() {
      var values = [null, undefined, NaN, true, false, 0, 1, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY, '', 'a', [], {}, [1, 'a', false], {a:1,b:'a',c:false}, function() {}];
      values.forEach(function(value, index) {
        var key = 'key' + index;
        cache.put(key, value);
        expect(cache.get(key)).to.deep.equal(value);
      });
    });

    it('should not set a timeout given no expiration time', function() {
      cache.put('key', 'value');
      clock.tick(1000);
      expect(cache.get('key')).to.equal('value');
    });

    it('should return the corresponding value of a non-expired key in the cache', function() {
      cache.put('key', 'value', 1000);
      clock.tick(999);
      expect(cache.get('key')).to.equal('value');
    });

    it('should return null given an expired key', function() {
      cache.put('key', 'value', 1000);
      clock.tick(1000);
      expect(cache.get('key')).to.be.null;
    });

    it('should return null given an expired key', function() {
      cache.put('key', 'value', 1000);
      clock.tick(1000);
      expect(cache.get('key')).to.be.null;
    });

    it('should return null given a key which is a property on the Object prototype', function() {
      expect(cache.get('toString')).to.be.null;
    });

    it('should allow reading the value for a key which is a property on the Object prototype', function() {
      cache.put('toString', 'value');
      expect(cache.get('toString')).to.equal('value');
    });
  });

  describe('size()', function() {
    before(function() {
      cache.debug(false);
    });

    it('should return 0 given a fresh cache', function() {
      expect(cache.size()).to.equal(0);
    });

    it('should return 1 after adding a single item to the cache', function() {
      cache.put('key', 'value');
      expect(cache.size()).to.equal(1);
    });

    it('should return 3 after adding three items to the cache', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.size()).to.equal(3);
    });

    it('should not multi-count duplicate items added to the cache', function() {
      cache.put('key', 'value1');
      expect(cache.size()).to.equal(1);
      cache.put('key', 'value2');
      expect(cache.size()).to.equal(1);
    });

    it('should update when a key in the cache expires', function() {
      cache.put('key', 'value', 1000);
      expect(cache.size()).to.equal(1);
      clock.tick(999);
      expect(cache.size()).to.equal(1);
      clock.tick(1);
      expect(cache.size()).to.equal(0);
    });
  });

  describe('memsize()', function() {
    before(function() {
      cache.debug(false);
    });

    it('should return 0 given a fresh cache', function() {
      expect(cache.memsize()).to.equal(0);
    });

    it('should return 1 after adding a single item to the cache', function() {
      cache.put('key', 'value');
      expect(cache.memsize()).to.equal(1);
    });

    it('should return 3 after adding three items to the cache', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.memsize()).to.equal(3);
    });

    it('should not multi-count duplicate items added to the cache', function() {
      cache.put('key', 'value1');
      expect(cache.memsize()).to.equal(1);
      cache.put('key', 'value2');
      expect(cache.memsize()).to.equal(1);
    });

    it('should update when a key in the cache expires', function() {
      cache.put('key', 'value', 1000);
      expect(cache.memsize()).to.equal(1);
      clock.tick(999);
      expect(cache.memsize()).to.equal(1);
      clock.tick(1);
      expect(cache.memsize()).to.equal(0);
    });
  });

  describe('debug()', function() {
    it('should not count cache hits when false', function() {
      cache.debug(false);
      cache.put('key', 'value');
      cache.get('key');
      expect(cache.hits()).to.equal(0);
    });

    it('should not count cache misses when false', function() {
      cache.debug(false);
      cache.put('key', 'value');
      cache.get('miss1');
      expect(cache.misses()).to.equal(0);
    });

    it('should count cache hits when true', function() {
      cache.debug(true);
      cache.put('key', 'value');
      cache.get('key');
      expect(cache.hits()).to.equal(1);
    });

    it('should count cache misses when true', function() {
      cache.debug(true);
      cache.put('key', 'value');
      cache.get('miss1');
      expect(cache.misses()).to.equal(1);
    });
  });

  describe('hits()', function() {
    before(function() {
      cache.debug(true);
    });

    it('should return 0 given an empty cache', function() {
      expect(cache.hits()).to.equal(0);
    });

    it('should return 0 given a non-empty cache which has not been accessed', function() {
      cache.put('key', 'value');
      expect(cache.hits()).to.equal(0);
    });

    it('should return 0 given a non-empty cache which has had only misses', function() {
      cache.put('key', 'value');
      cache.get('miss1');
      cache.get('miss2');
      cache.get('miss3');
      expect(cache.hits()).to.equal(0);
    });

    it('should return 1 given a non-empty cache which has had a single hit', function() {
      cache.put('key', 'value');
      cache.get('key');
      expect(cache.hits()).to.equal(1);
    });

    it('should return 3 given a non-empty cache which has had three hits on the same key', function() {
      cache.put('key', 'value');
      cache.get('key');
      cache.get('key');
      cache.get('key');
      expect(cache.hits()).to.equal(3);
    });

    it('should return 3 given a non-empty cache which has had three hits across many keys', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      cache.get('key1');
      cache.get('key2');
      cache.get('key3');
      expect(cache.hits()).to.equal(3);
    });

    it('should return the correct value after a sequence of hits and misses', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      cache.get('key1');
      cache.get('miss');
      cache.get('key3');
      expect(cache.hits()).to.equal(2);
    });

    it('should not count hits for expired keys', function() {
      cache.put('key', 'value', 1000);
      cache.get('key');
      expect(cache.hits()).to.equal(1);
      clock.tick(999);
      cache.get('key');
      expect(cache.hits()).to.equal(2);
      clock.tick(1);
      cache.get('key');
      expect(cache.hits()).to.equal(2);
    });
  });

  describe('misses()', function() {
    before(function() {
      cache.debug(true);
    });

    it('should return 0 given an empty cache', function() {
      expect(cache.misses()).to.equal(0);
    });

    it('should return 0 given a non-empty cache which has not been accessed', function() {
      cache.put('key', 'value');
      expect(cache.misses()).to.equal(0);
    });

    it('should return 0 given a non-empty cache which has had only hits', function() {
      cache.put('key', 'value');
      cache.get('key');
      cache.get('key');
      cache.get('key');
      expect(cache.misses()).to.equal(0);
    });

    it('should return 1 given a non-empty cache which has had a single miss', function() {
      cache.put('key', 'value');
      cache.get('miss');
      expect(cache.misses()).to.equal(1);
    });

    it('should return 3 given a non-empty cache which has had three misses', function() {
      cache.put('key', 'value');
      cache.get('miss1');
      cache.get('miss2');
      cache.get('miss3');
      expect(cache.misses()).to.equal(3);
    });

    it('should return the correct value after a sequence of hits and misses', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      cache.get('key1');
      cache.get('miss');
      cache.get('key3');
      expect(cache.misses()).to.equal(1);
    });

    it('should count misses for expired keys', function() {
      cache.put('key', 'value', 1000);
      cache.get('key');
      expect(cache.misses()).to.equal(0);
      clock.tick(999);
      cache.get('key');
      expect(cache.misses()).to.equal(0);
      clock.tick(1);
      cache.get('key');
      expect(cache.misses()).to.equal(1);
    });
  });

  describe('keys()', function() {
    before(function() {
      cache.debug(false);
    });

    it('should return an empty array given an empty cache', function() {
      expect(cache.keys()).to.deep.equal([]);
    });

    it('should return a single key after adding a single item to the cache', function() {
      cache.put('key', 'value');
      expect(cache.keys()).to.deep.equal(['key']);
    });

    it('should return 3 keys after adding three items to the cache', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2');
      cache.put('key3', 'value3');
      expect(cache.keys()).to.deep.equal(['key1', 'key2', 'key3']);
    });

    it('should not multi-count duplicate items added to the cache', function() {
      cache.put('key', 'value1');
      expect(cache.keys()).to.deep.equal(['key']);
      cache.put('key', 'value2');
      expect(cache.keys()).to.deep.equal(['key']);
    });

    it('should update when a key in the cache expires', function() {
      cache.put('key', 'value', 1000);
      expect(cache.keys()).to.deep.equal(['key']);
      clock.tick(999);
      expect(cache.keys()).to.deep.equal(['key']);
      clock.tick(1);
      expect(cache.keys()).to.deep.equal([]);
    });
  });

  describe('export()', function() {
    var START_TIME = 10000;

    var BASIC_EXPORT = JSON.stringify({
      key: {
        value: 'value',
        expire: START_TIME + 1000,
      },
    });

    before(function() {
      cache.debug(false);
    });

    beforeEach(function() {
      clock.tick(START_TIME);
    });

    it('should return an empty object given an empty cache', function() {
      expect(cache.exportJson()).to.equal(JSON.stringify({}));
    });

    it('should return a single record after adding a single item to the cache', function() {
      cache.put('key', 'value', 1000);
      expect(cache.exportJson()).to.equal(BASIC_EXPORT);
    });

    it('should return multiple records with expiry', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2', 1000);
      expect(cache.exportJson()).to.equal(JSON.stringify({
        key1: {
          value: 'value1',
          expire: 'NaN',
        },
        key2: {
          value: 'value2',
          expire: START_TIME + 1000,
        },
      }));
    });

    it('should update when a key in the cache expires', function() {
      cache.put('key', 'value', 1000);
      expect(cache.exportJson()).to.equal(BASIC_EXPORT);
      clock.tick(999);
      expect(cache.exportJson()).to.equal(BASIC_EXPORT);
      clock.tick(1);
      expect(cache.exportJson()).to.equal(JSON.stringify({}));
    });
  });

  describe('import()', function() {
    var START_TIME = 10000;

    var BASIC_EXPORT = JSON.stringify({
      key: {
        value: 'value',
        expire: START_TIME + 1000,
      },
    });

    before(function() {
      cache.debug(false);
    });

    beforeEach(function() {
      clock.tick(START_TIME);
    });

    it('should import an empty object into an empty cache', function() {
      var exportedJson = cache.exportJson();

      cache.clear();
      cache.importJson(exportedJson);

      expect(cache.exportJson()).to.equal(JSON.stringify({}));
    });

    it('should import records into an empty cache', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2', 1000);
      var exportedJson = cache.exportJson();

      cache.clear();
      cache.importJson(exportedJson);

      expect(cache.exportJson()).to.equal(JSON.stringify({
        key1: {
          value: 'value1',
          expire: 'NaN',
        },
        key2: {
          value: 'value2',
          expire: START_TIME + 1000,
        },
      }));
    });

    it('should import records into an already-existing cache', function() {
      cache.put('key1', 'value1');
      cache.put('key2', 'value2', 1000);
      var exportedJson = cache.exportJson();

      cache.put('key1', 'changed value', 5000);
      cache.put('key3', 'value3', 500);

      cache.importJson(exportedJson);

      expect(cache.exportJson()).to.equal(JSON.stringify({
        key1: {
          value: 'value1',
          expire: 'NaN',
        },
        key2: {
          value: 'value2',
          expire: START_TIME + 1000,
        },
        key3: {
          value: 'value3',
          expire: START_TIME + 500,
        },
      }));
    });

    it('should import records into an already-existing cache and skip duplicates', function() {
      cache.debug(true);

      cache.put('key1', 'value1');
      cache.put('key2', 'value2', 1000);
      var exportedJson = cache.exportJson();

      cache.clear();
      cache.put('key1', 'changed value', 5000);
      cache.put('key3', 'value3', 500);

      cache.importJson(exportedJson, { skipDuplicates: true });

      expect(cache.exportJson()).to.equal(JSON.stringify({
        key1: {
          value: 'changed value',
          expire: START_TIME + 5000,
        },
        key3: {
          value: 'value3',
          expire: START_TIME + 500,
        },
        key2: {
          value: 'value2',
          expire: START_TIME + 1000,
        },
      }));
    });

    it('should import with updated expire times', function() {
      cache.put('key1', 'value1', 500);
      cache.put('key2', 'value2', 1000);
      var exportedJson = cache.exportJson();

      var tickAmount = 750;
      clock.tick(tickAmount);

      cache.importJson(exportedJson);

      expect(cache.exportJson()).to.equal(JSON.stringify({
        key2: {
          value: 'value2',
          expire: START_TIME + tickAmount + 250,
        },
      }));
    });

    it('should return the new size', function() {
      cache.put('key1', 'value1', 500);
      var exportedJson = cache.exportJson();

      cache.clear();
      cache.put('key2', 'value2', 1000);
      expect(cache.size()).to.equal(1);

      var size = cache.importJson(exportedJson);
      expect(size).to.equal(2);
      expect(cache.size()).to.equal(2);
    });
  });

  describe('Cache()', function() {
    it('should return a new cache instance when called', function() {
      var cache1 = new Cache(),
        cache2 = new Cache();
      cache1.put('key', 'value1');
      expect(cache1.keys()).to.deep.equal(['key']);
      expect(cache2.keys()).to.deep.equal([]);
      cache2.put('key', 'value2');
      expect(cache1.get('key')).to.equal('value1');
      expect(cache2.get('key')).to.equal('value2');
    });
  });

});
