import { type LogLevel } from '../log';
export declare const seekToTime: ({ element, desiredTime, logLevel, mountTime, }: {
    element: HTMLVideoElement;
    desiredTime: number;
    logLevel: LogLevel;
    mountTime: number;
}) => {
    wait: Promise<number>;
    cancel: () => void;
};
export declare const seekToTimeMultipleUntilRight: ({ element, desiredTime, fps, logLevel, mountTime, }: {
    element: HTMLVideoElement;
    desiredTime: number;
    fps: number;
    logLevel: LogLevel;
    mountTime: number;
}) => {
    prom: Promise<void>;
    cancel: () => void;
};
