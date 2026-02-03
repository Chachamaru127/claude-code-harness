export declare const validateStartFromProps: (startFrom: number | undefined, endAt: number | undefined) => void;
export declare const validateTrimProps: (trimBefore: number | undefined, trimAfter: number | undefined) => void;
export declare const validateMediaTrimProps: ({ startFrom, endAt, trimBefore, trimAfter, }: {
    startFrom: number | undefined;
    endAt: number | undefined;
    trimBefore: number | undefined;
    trimAfter: number | undefined;
}) => void;
export declare const resolveTrimProps: ({ startFrom, endAt, trimBefore, trimAfter, }: {
    startFrom: number | undefined;
    endAt: number | undefined;
    trimBefore: number | undefined;
    trimAfter: number | undefined;
}) => {
    trimBeforeValue: number | undefined;
    trimAfterValue: number | undefined;
};
