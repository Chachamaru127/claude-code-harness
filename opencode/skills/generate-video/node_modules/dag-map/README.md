# dag-map [![Build Status](https://travis-ci.org/krisselden/dag-map.png?branch=master)](https://travis-ci.org/krisselden/dag-map)
A [directed acyclic graph](http://en.wikipedia.org/wiki/Directed_acyclic_graph) library for JavaScript.

In addition to being a DAG implmentation, it also provides value storage on the
vertices. So in-short, it is a key/value DAG.


## Downloads

## API

```js
  // create a new draph;
  var graph = new DAG();

  // add some nodes
  graph.add('foo');
  graph.add('bar');
  graph.add('baz');

  // currently, no edges exist between these nodes, so lets add some

  graph.addEdge('foo', 'bar');

  // we now have an edge from 'foo' -> 'bar';

  graph.addEdge('bar', 'baz');

  // we now have an edge from 'foo' -> 'bar' -> 'baz';

  // to have the graph calculate this topSort for us, we can use the topSort
  // iterator, to build an ordered
  var vertices = [];

  graph.topsort(function(vertex, path){
    vertices.push(vertex.name);
  });

  vertices === [ 'foo', 'bar', 'baz' ];
```

## Developing

* `npm install`
* `npm test` runs the tests headless
* `npm run test:server` runs the tests and the development server
* `npm build` builds the development dist
* `npm build:production` builds the production dist
