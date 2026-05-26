/**
 * @file assets.manifest.ts
 * @description Auto-generated Zod schema for AssetManifest
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/assets.manifest.schema.json
 *           All $ref references are resolved during generation.
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * Asset manifest for video generation with SHA-256 hash management (version 1.0.0)
 */
export const AssetsManifestSchema = z.object({ "version": z.string().regex(new RegExp("^\\d+\\.\\d+\\.\\d+$")).describe("Schema version"), "generated_at": z.string().datetime({ offset: true }).describe("ISO 8601 timestamp when manifest was generated"), "project": z.object({ "name": z.string().describe("Project name").optional(), "video_id": z.string().regex(new RegExp("^video-\\d{8}-[a-z0-9]{8}$")).describe("Unique video ID").optional() }).describe("Project metadata").optional(), "assets": z.array(z.object({ "id": z.string().describe("Unique asset identifier"), "path": z.string().describe("Relative path from output directory"), "type": z.enum(["image","audio","video","font","data"]).describe("Asset type"), "hash": z.string().regex(new RegExp("^[a-f0-9]{64}$")).describe("SHA-256 hash of the asset file"), "size": z.number().int().gte(0).describe("File size in bytes"), "mime_type": z.string().describe("MIME type of the asset").optional(), "dimensions": z.object({ "width": z.number().int().gte(1), "height": z.number().int().gte(1) }).describe("Image or video dimensions").optional(), "duration": z.number().gte(0).describe("Duration in seconds (for audio/video)").optional(), "source": z.object({ "type": z.enum(["generated","captured","uploaded","template"]).describe("Source type").optional(), "generator": z.string().describe("Generator name (if generated)").optional(), "prompt": z.string().describe("Generation prompt (if AI-generated)").optional(), "seed": z.number().int().describe("Random seed for deterministic generation").optional(), "url": z.string().describe("Original URL (if downloaded)").optional() }).describe("Asset source information").optional(), "metadata": z.record(z.unknown()).describe("Additional metadata").optional(), "created_at": z.string().datetime({ offset: true }).describe("Asset creation timestamp").optional(), "verified_at": z.string().datetime({ offset: true }).describe("Last hash verification timestamp").optional() })).describe("List of all assets with hash verification") }).describe("Asset manifest for video generation with SHA-256 hash management (version 1.0.0)")

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
  description: 'Asset manifest for video generation with SHA-256 hash management (version 1.0.0)',
} as const;
