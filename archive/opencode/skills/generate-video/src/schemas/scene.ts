/**
 * @file scene.ts
 * @description Auto-generated Zod schema for Video Scene Schema
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/scene.schema.json
 *           All $ref references are resolved during generation.
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * Defines an individual video scene with content, direction, and assets
 */
export const SceneSchema = z.object({ "scene_id": z.string().regex(new RegExp("^[a-z0-9-]+$")).describe("Unique identifier for the scene"), "section_id": z.string().regex(new RegExp("^[a-z0-9-]+$")).describe("ID of the section this scene belongs to"), "order": z.number().int().gte(0).describe("Order of the scene within its section (0-indexed)"), "type": z.enum(["intro","ui-demo","architecture","code-highlight","changelog","cta","feature-highlight","problem-promise","workflow","objection","custom"]).describe("Type of scene content"), "content": z.object({ "text": z.string().describe("Primary text content for the scene").optional(), "image": z.string().describe("Path to image asset (relative or absolute)").optional(), "duration_ms": z.number().int().gte(100).describe("Duration of the scene in milliseconds"), "title": z.string().describe("Scene title").optional(), "subtitle": z.string().describe("Scene subtitle or tagline").optional(), "url": z.string().url().describe("URL for Playwright capture or external resource").optional(), "actions": z.array(z.object({ "type": z.enum(["click","type","wait","scroll","hover","keypress"]).optional(), "selector": z.string().describe("CSS selector or data-testid").optional(), "value": z.unknown().superRefine((x, ctx) => {
    const schemas = [z.string(), z.number()];
    const errors = schemas.reduce<z.ZodError[]>(
      (errors, schema) =>
        ((result) =>
          result.error ? [...errors, result.error] : errors)(
          schema.safeParse(x),
        ),
      [],
    );
    if (schemas.length - errors.length !== 1) {
      ctx.addIssue({
        path: ctx.path,
        code: "invalid_union",
        unionErrors: errors,
        message: "Invalid input: Should pass single schema",
      });
    }
  }).describe("Value for type actions or wait duration").optional() })).describe("Playwright actions for UI demo scenes").optional(), "mermaid": z.string().describe("Mermaid diagram definition for architecture scenes").optional(), "code": z.object({ "language": z.string().optional(), "snippet": z.string().optional(), "highlights": z.array(z.number().int()).describe("Line numbers to highlight").optional() }).describe("Code snippet for code-highlight scenes").optional() }).describe("Scene content configuration"), "direction": z.object({ "transition": z.object({ "in": z.enum(["fade","slide_in","zoom","cut"]).default("fade"), "out": z.enum(["fade","slide_in","zoom","cut"]).default("fade"), "duration_ms": z.number().int().gte(0).lte(2000).describe("Transition duration in milliseconds").default(500) }).describe("Transition effects").optional(), "emphasis": z.object({ "effect": z.enum(["glitch","pulse","shake","highlight","none"]).optional(), "timing": z.string().describe("When to apply effect (e.g., '2s', '50%')").optional() }).describe("Emphasis and highlighting").optional(), "background": z.object({ "type": z.enum(["solid","gradient","image","video","particles"]).optional(), "value": z.string().describe("Color, gradient definition, or asset path").optional(), "opacity": z.number().gte(0).lte(1).default(1) }).describe("Background configuration").optional(), "camera": z.object({ "movement": z.enum(["static","pan","zoom","rotate","parallax"]).optional(), "start": z.record(z.unknown()).describe("Starting position/rotation").optional(), "end": z.record(z.unknown()).describe("Ending position/rotation").optional() }).describe("Camera movement (3D effects)").optional() }).describe("Visual direction and effects for the scene").optional(), "assets": z.array(z.object({ "type": z.enum(["image","video","audio","font","data"]), "source": z.string().describe("Path or URL to the asset"), "generated": z.boolean().describe("Whether this asset was AI-generated").default(false), "metadata": z.object({ "width": z.number().int().optional(), "height": z.number().int().optional(), "duration_ms": z.number().int().optional(), "format": z.string().optional() }).describe("Additional metadata about the asset").optional() })).describe("Assets used in this scene").optional(), "audio": z.object({ "narration": z.object({ "text": z.string().describe("Narration text").optional(), "file": z.string().describe("Path to narration audio file").optional(), "start_offset_ms": z.number().int().describe("Delay before narration starts (typically 1000ms)").default(1000) }).optional(), "sfx": z.array(z.object({ "file": z.string().optional(), "timing_ms": z.number().int().optional(), "volume": z.number().gte(0).lte(1).optional() })).describe("Sound effects").optional() }).describe("Audio configuration for the scene").optional(), "template": z.string().describe("Template name if using a predefined template").optional(), "notes": z.string().describe("Internal notes for this scene").optional() }).describe("Defines an individual video scene with content, direction, and assets")

/**
 * Inferred TypeScript type from Zod schema
 */
export type Scene = z.infer<typeof SceneSchema>;

/**
 * Schema metadata
 */
export const SceneMeta = {
  version: '1.0.0',
  title: 'Video Scene Schema',
  description: 'Defines an individual video scene with content, direction, and assets',
} as const;
