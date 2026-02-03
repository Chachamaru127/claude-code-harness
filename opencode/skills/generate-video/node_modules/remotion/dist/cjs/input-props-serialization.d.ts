export type SerializedJSONWithCustomFields = {
    serializedString: string;
    customDateUsed: boolean;
    customFileUsed: boolean;
    mapUsed: boolean;
    setUsed: boolean;
};
export declare const DATE_TOKEN = "remotion-date:";
export declare const FILE_TOKEN = "remotion-file:";
export declare const serializeJSONWithSpecialTypes: ({ data, indent, staticBase, }: {
    data: Record<string, unknown>;
    indent: number | undefined;
    staticBase: string | null;
}) => SerializedJSONWithCustomFields;
export declare const deserializeJSONWithSpecialTypes: <T = Record<string, unknown>>(data: string) => T;
export declare const serializeThenDeserialize: (props: Record<string, unknown>) => Record<string, unknown>;
export declare const serializeThenDeserializeInStudio: (props: Record<string, unknown>) => Record<string, unknown>;
