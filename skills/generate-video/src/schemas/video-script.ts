/**
 * @file video-script.ts
 * @description Auto-generated Zod schema for Video Script Schema
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/video-script.schema.json
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * Complete video script with metadata, scenes, and output settings
 */
export const VideoScriptSchema = z.object({ "metadata": z.object({ "title": z.string().min(1).max(200).describe("Video title"), "description": z.string().describe("Video description").optional(), "version": z.string().regex(new RegExp("^[0-9]+\\.[0-9]+\\.[0-9]+$")).describe("Script version"), "created_at": z.string().datetime({ offset: true }).describe("ISO 8601 timestamp of script creation"), "updated_at": z.string().datetime({ offset: true }).describe("ISO 8601 timestamp of last update").optional(), "author": z.string().describe("Script author or generator").optional(), "project": z.string().describe("Project name or identifier").optional(), "video_type": z.enum(["lp-teaser","intro-demo","release-notes","architecture","onboarding","custom"]).describe("Type of video").optional(), "tags": z.array(z.string()).describe("Categorization tags").optional(), "scenario_id": z.string().describe("Reference to the scenario this script is based on").optional() }).describe("Metadata about the video script"), "scenes": z.array(z.any()).min(1).describe("Ordered list of video scenes"), "total_duration_ms": z.number().int().gte(0).describe("Total duration of the video in milliseconds"), "output_settings": z.object({ "width": z.number().int().gte(320).lte(7680).describe("Video width in pixels"), "height": z.number().int().gte(240).lte(4320).describe("Video height in pixels"), "fps": z.union([z.literal(24), z.literal(25), z.literal(30), z.literal(50), z.literal(60)]).describe("Frames per second").default(30), "codec": z.enum(["h264","h265","vp8","vp9","av1"]).describe("Video codec").default("h264"), "format": z.enum(["mp4","webm","mov","gif"]).describe("Output format").default("mp4"), "quality": z.enum(["low","medium","high","ultra"]).describe("Output quality preset").default("high"), "bitrate": z.string().describe("Video bitrate (e.g., '5M', '10M')").optional(), "preset": z.enum(["240p","360p","480p","720p","1080p","1440p","4k","custom"]).describe("Encoding preset for resolution").optional() }).describe("Video output configuration"), "audio_settings": z.object({ "bgm": z.object({ "file": z.string().describe("Path to BGM file").optional(), "volume": z.number().gte(0).lte(1).describe("BGM volume (0.0 - 1.0)").default(0.3), "fade_in_ms": z.number().int().gte(0).describe("Fade in duration in milliseconds").default(1000), "fade_out_ms": z.number().int().gte(0).describe("Fade out duration in milliseconds").default(2000), "loop": z.boolean().describe("Whether to loop the BGM").default(true) }).describe("Background music configuration").optional(), "master_volume": z.number().gte(0).lte(1).describe("Master volume (0.0 - 1.0)").default(1) }).describe("Global audio settings").optional(), "branding": z.object({ "logo": z.string().describe("Path to logo file").optional(), "colors": z.object({ "primary": z.string().describe("Primary brand color (hex or rgb)").optional(), "secondary": z.string().describe("Secondary brand color").optional(), "accent": z.string().describe("Accent color").optional(), "background": z.string().describe("Default background color").optional(), "text": z.string().describe("Default text color").optional() }).optional(), "fonts": z.object({ "primary": z.string().describe("Primary font family or path to font file").optional(), "secondary": z.string().describe("Secondary font family").optional(), "monospace": z.string().describe("Monospace font for code").optional() }).optional() }).describe("Branding configuration").optional(), "transitions": z.object({ "default_duration_ms": z.number().int().gte(0).lte(2000).describe("Default transition duration in milliseconds").default(500), "overlap_ms": z.number().int().gte(0).lte(1000).describe("Overlap duration between scenes (for cross-fade)").default(450), "type": z.enum(["fade","slide","zoom","none"]).describe("Default transition type").default("fade") }).describe("Global transition settings").optional(), "notes": z.string().describe("General notes about the video script").optional() }).describe("Complete video script with metadata, scenes, and output settings")

/**
 * Inferred TypeScript type from Zod schema
 */
export type VideoScript = z.infer<typeof VideoScriptSchema>;

/**
 * Schema metadata
 */
export const VideoScriptMeta = {
  version: '1.0.0',
  title: 'Video Script Schema',
  description: 'Complete video script with metadata, scenes, and output settings',
} as const;
