import type { ComponentPropsWithRef, ComponentType, ExoticComponent } from 'react';
import type { CompProps } from './Composition.js';
type LazyExoticComponent<T extends ComponentType<any>> = ExoticComponent<ComponentPropsWithRef<T>> & {
    readonly _result: T;
};
export declare const useLazyComponent: <Props>({ compProps, componentName, noSuspense, }: {
    compProps: CompProps<Props>;
    componentName: string;
    noSuspense: boolean;
}) => LazyExoticComponent<ComponentType<Props>> | ComponentType<Props>;
export {};
