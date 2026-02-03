export default function visit(vertex, fn, visited, path) {
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
    visit(vertices[names[i]], fn, visited, path);
  }
  fn(vertex, path);
  path.pop();
}

