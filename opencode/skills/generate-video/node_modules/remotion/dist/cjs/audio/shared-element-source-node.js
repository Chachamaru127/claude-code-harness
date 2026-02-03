"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.makeSharedElementSourceNode = void 0;
const makeSharedElementSourceNode = ({ audioContext, ref, }) => {
    let connected = null;
    let disposed = false;
    // We must allow this to cleanup and create a new one due to strict mode.
    return {
        attemptToConnect: () => {
            if (disposed) {
                throw new Error('SharedElementSourceNode has been disposed');
            }
            if (!connected && ref.current) {
                const mediaElementSourceNode = audioContext.createMediaElementSource(ref.current);
                connected = mediaElementSourceNode;
            }
        },
        get: () => {
            if (!connected) {
                throw new Error('Audio element not connected');
            }
            return connected;
        },
        cleanup: () => {
            if (connected) {
                connected.disconnect();
                connected = null;
            }
            disposed = true;
        },
    };
};
exports.makeSharedElementSourceNode = makeSharedElementSourceNode;
