import type { VolumeProp } from './volume-prop.js';
export declare const validateMediaProps: (props: {
    volume: VolumeProp | undefined;
    playbackRate: number | undefined;
}, component: "Html5Video" | "Html5Audio" | "Audio" | "Video") => void;
