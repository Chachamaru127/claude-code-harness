/**
 * @file assets.manifest.ts
 * @description Auto-generated Zod schema for AssetManifest
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/assets.manifest.schema.json
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * Asset manifest for video generation with SHA-256 hash management
 */
import { z } from "zod"

export const AssetsManifest = z.object({ "version": z.string().regex(new RegExp("^\\d+\\.\\d+\\.\\d+$")).describe("Schema version"), "generated_at": z.string().datetime({ offset: true }).describe("ISO 8601 timestamp when manifest was generated"), "project": z.object({ "name": z.string().describe("Project name").optional(), "video_id": z.string().regex(new RegExp("^video-\\d{8}-[a-z0-9]{8}$")).describe("Unique video ID").optional() }).describe("Project metadata").optional(), "assets": z.array(z.any()).describe("List of all assets with hash verification") }).describe("Asset manifest for video generation with SHA-256 hash management")


/**
 * Inferred TypeScript type from Zod schema
 */
export type AssetsManifest = z.infer<typeof AssetsManifestSchema>;

/**
 * Schema metadata
 */
export const AssetsManifestMeta = {
  version: '1.0.0',
  title: 'AssetManifest',
  description: 'Asset manifest for video generation with SHA-256 hash management',
} as const;
