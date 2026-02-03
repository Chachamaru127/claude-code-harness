(function() {
    "use strict";
    var lib$dag$map$platform$$platform;

    /* global self */
    if (typeof self === 'object') {
      lib$dag$map$platform$$platform = self;

    /* global global */
    } else if (typeof global === 'object') {
      lib$dag$map$platform$$platform = global;
    } else {
      throw new Error('no global: `self` or `global` found');
    }

    var lib$dag$map$platform$$default = lib$dag$map$platform$$platform;
    function lib$vertex$$Vertex(name) {
      this.name = name;
      this.incoming = {};
      this.incomingNames = [];
      this.hasOutgoing = false;
      this.value = null;
    }
    var lib$vertex$$default = lib$vertex$$Vertex;
    function lib$visit$$visit(vertex, fn, visited, path) {
      var name = vertex.name;
      var vertices = vertex.incoming;
      var names = vertex.incomingNames;
      var len = names.length;
      var i;

      if (!visited) {
        visited = {};
      }
      if (!path) {
        path = [];
      }
      if (visited.hasOwnProperty(name)) {
        return;
      }
      path.push(name);
      visited[name] = true;
      for (i = 0; i < len; i++) {
        lib$visit$$visit(vertices[names[i]], fn, visited, path);
      }
      fn(vertex, path);
      path.pop();
    }

    var lib$visit$$default = lib$visit$$visit;
    function lib$dag$map$$DAG() {
      this.names = [];
      this.vertices = Object.create(null);
    }

    var lib$dag$map$$default = lib$dag$map$$DAG;

    /**
     * Adds a vertex entry to the graph unless it is already added.
     *
     * @private
     * @method add
     * @param {String} name The name of the vertex to add
     */
    lib$dag$map$$DAG.prototype.add = function(name) {
      if (!name) {
        throw new Error("Can't add Vertex without name");
      }
      if (this.vertices[name] !== undefined) {
        return this.vertices[name];
      }
      var vertex = new lib$vertex$$default(name);
      this.vertices[name] = vertex;
      this.names.push(name);
      return vertex;
    };

    /**
     * Adds a vertex to the graph and sets its value.
     *
     * @private
     * @method map
     * @param {String} name The name of the vertex.
     * @param         value The value to put in the vertex.
     */
    lib$dag$map$$DAG.prototype.map = function(name, value) {
      this.add(name).value = value;
    };

    /**
     * Connects the vertices with the given names, adding them to the graph if
     * necessary, only if this does not produce is any circular dependency.
     *
     * @private
     * @method addEdge
     * @param {String} fromName The name the vertex where the edge starts.
     * @param {String} toName The name the vertex where the edge ends.
     */
    lib$dag$map$$DAG.prototype.addEdge = function(fromName, toName) {
      if (!fromName || !toName || fromName === toName) {
        return;
      }
      var from = this.add(fromName);
      var to = this.add(toName);
      if (to.incoming.hasOwnProperty(fromName)) {
        return;
      }
      function checkCycle(vertex, path) {
        if (vertex.name === toName) {
          throw new Error("cycle detected: " + toName + " <- " + path.join(" <- "));
        }
      }
      lib$visit$$default(from, checkCycle);
      from.hasOutgoing = true;
      to.incoming[fromName] = from;
      to.incomingNames.push(fromName);
    };

    /**
     * Visits all the vertex of the graph calling the given function with each one,
     * ensuring that the vertices are visited respecting their precedence.
     *
     * @method  topsort
     * @param {Function} fn The function to be invoked on each vertex.
     */
    lib$dag$map$$DAG.prototype.topsort = function(fn) {
      var visited = {};
      var vertices = this.vertices;
      var names = this.names;
      var len = names.length;
      var i, vertex;

      for (i = 0; i < len; i++) {
        vertex = vertices[names[i]];
        if (!vertex.hasOutgoing) {
          lib$visit$$default(vertex, fn, visited);
        }
      }
    };

    /**
     * Adds a vertex with the given name and value to the graph and joins it with the
     * vertices referenced in _before_ and _after_. If there isn't vertices with those
     * names, they are added too.
     *
     * If either _before_ or _after_ are falsy/empty, the added vertex will not have
     * an incoming/outgoing edge.
     *
     * @method addEdges
     * @param {String} name The name of the vertex to be added.
     * @param         value The value of that vertex.
     * @param        before An string or array of strings with the names of the vertices before
     *                      which this vertex must be visited.
     * @param         after An string or array of strings with the names of the vertex after
     *                      which this vertex must be visited.
     *
     */
    lib$dag$map$$DAG.prototype.addEdges = function(name, value, before, after) {
      var i;
      this.map(name, value);
      if (before) {
        if (typeof before === 'string') {
          this.addEdge(name, before);
        } else {
          for (i = 0; i < before.length; i++) {
            this.addEdge(name, before[i]);
          }
        }
      }
      if (after) {
        if (typeof after === 'string') {
          this.addEdge(after, name);
        } else {
          for (i = 0; i < after.length; i++) {
            this.addEdge(after[i], name);
          }
        }
      }
    };

    /* global define:true module:true window: true */
    if (typeof define === 'function' && define.amd) {
      define(function() { return lib$dag$map$$default; });
    } else if (typeof module !== 'undefined' && module.exports) {
      module.exports = lib$dag$map$$default;
    } else if (typeof lib$dag$map$platform$$default !== 'undefined') {
      lib$dag$map$platform$$default['DAG'] = lib$dag$map$$default;
    }
}).call(this);

//# sourceMappingURL=dag-map.js.map