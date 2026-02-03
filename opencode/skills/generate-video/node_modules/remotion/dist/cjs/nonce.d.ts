export type TNonceContext = {
    getNonce: () => number;
};
export declare const NonceContext: import("react").Context<TNonceContext>;
export declare const useNonce: () => number;
