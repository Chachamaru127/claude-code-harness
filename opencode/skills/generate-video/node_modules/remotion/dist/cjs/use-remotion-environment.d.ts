import type { RemotionEnvironment } from './remotion-environment-context';
/**
 * @description A React hook that provides information about the current Remotion Environment. This is the preferred way to access environment information in React components as it will support future scoped contexts.
 * @see [Documentation](https://remotion.dev/docs/use-remotion-environment)
 */
export declare const useRemotionEnvironment: () => RemotionEnvironment;
