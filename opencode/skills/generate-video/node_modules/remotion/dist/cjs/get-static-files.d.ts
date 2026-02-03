export declare const getStaticFiles: () => StaticFile[];
export type StaticFile = {
    /**
     * A string that you can pass to the `src` attribute of an `<Audio>`, `<Img>`, `<Video>`, `<Html5Audio>`, `<Html5Video>` or `<OffthreadVideo>` element.
     */
    src: string;
    /**
     * The filepath of the file, relative to the public folder.
     * Example: `subfolder/image.png`
     */
    name: string;
    sizeInBytes: number;
    /**
     * UNIX timestamp in milliseconds
     */
    lastModified: number;
};
