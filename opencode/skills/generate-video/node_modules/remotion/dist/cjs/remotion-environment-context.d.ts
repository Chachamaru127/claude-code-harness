import React from 'react';
export type RemotionEnvironment = {
    isStudio: boolean;
    isRendering: boolean;
    isClientSideRendering: boolean;
    isPlayer: boolean;
    isReadOnlyStudio: boolean;
};
export declare const RemotionEnvironmentContext: React.Context<RemotionEnvironment | null>;
