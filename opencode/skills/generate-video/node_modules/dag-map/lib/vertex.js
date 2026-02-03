
/**
 * DAG Vertex
 *
 * @class Vertex
 * @constructor
 */

export default function Vertex(name) {
  this.name = name;
  this.incoming = {};
  this.incomingNames = [];
  this.hasOutgoing = false;
  this.value = null;
}
