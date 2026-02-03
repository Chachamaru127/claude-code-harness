import React from 'react';
type NativeImgProps = Omit<React.DetailedHTMLProps<React.ImgHTMLAttributes<HTMLImageElement>, HTMLImageElement>, 'src'>;
export type ImgProps = NativeImgProps & {
    readonly maxRetries?: number;
    readonly pauseWhenLoading?: boolean;
    readonly delayRenderRetries?: number;
    readonly delayRenderTimeoutInMilliseconds?: number;
    readonly onImageFrame?: (imageElement: HTMLImageElement) => void;
    readonly src: string;
};
export declare const Img: React.ForwardRefExoticComponent<Omit<ImgProps, "ref"> & React.RefAttributes<HTMLImageElement>>;
export {};
