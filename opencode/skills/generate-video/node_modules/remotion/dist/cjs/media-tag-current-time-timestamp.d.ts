import React from 'react';
export declare const useCurrentTimeOfMediaTagWithUpdateTimeStamp: (mediaRef: React.RefObject<HTMLVideoElement | HTMLAudioElement | null>) => React.RefObject<{
    time: number;
    lastUpdate: number;
}>;
