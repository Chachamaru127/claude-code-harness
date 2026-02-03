import platform from './dag-map/platform';
import DAG from './dag-map';

/* global define:true module:true window: true */
if (typeof define === 'function' && define.amd) {
  define(function() { return DAG; });
} else if (typeof module !== 'undefined' && module.exports) {
  module.exports = DAG;
} else if (typeof platform !== 'undefined') {
  platform['DAG'] = DAG;
}
