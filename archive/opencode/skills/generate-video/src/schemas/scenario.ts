/**
 * @file scenario.ts
 * @description Auto-generated Zod schema for Video Scenario Schema
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/scenario.schema.json
 *           All $ref references are resolved during generation.
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * Defines the high-level structure of a video scenario with sections and metadata
 */
export const ScenarioSchema = z.object({ "title": z.string().min(1).max(200).describe("Title of the video scenario"), "description": z.string().min(1).max(1000).describe("Detailed description of the scenario purpose and content"), "sections": z.array(z.object({ "id": z.string().regex(new RegExp("^[a-z0-9-]+$")).describe("Unique identifier for the section"), "title": z.string().min(1).max(100).describe("Section title"), "description": z.string().min(1).max(500).describe("Section description and purpose"), "order": z.number().int().gte(0).describe("Order of the section in the scenario (0-indexed)"), "duration_estimate_ms": z.number().int().gte(0).describe("Estimated duration of this section in milliseconds").optional(), "tags": z.array(z.string().regex(new RegExp("^[a-z0-9-]+$"))).describe("Tags for categorizing the section").optional() })).min(1).describe("Ordered list of scenario sections"), "metadata": z.object({ "seed": z.string().regex(new RegExp("^[a-zA-Z0-9-]+$")).describe("Random seed used for generation (optional)").optional(), "version": z.string().regex(new RegExp("^[0-9]+\\.[0-9]+\\.[0-9]+$")).describe("Schema version"), "generated_at": z.string().datetime({ offset: true }).describe("ISO 8601 timestamp of scenario generation"), "generator": z.string().describe("Tool or agent that generated this scenario").optional(), "project_name": z.string().describe("Name of the project this scenario is for").optional(), "video_type": z.enum(["lp-teaser","intro-demo","release-notes","architecture","onboarding","custom"]).describe("Type of video (e.g., product-demo, release-notes, architecture)").optional(), "target_funnel": z.enum(["awareness","interest","consideration","decision","retention","advocacy"]).describe("Marketing funnel stage this video targets").optional() }).describe("Metadata about the scenario generation") }).describe("Defines the high-level structure of a video scenario with sections and metadata")

/**
 * Inferred TypeScript type from Zod schema
 */
export type Scenario = z.infer<typeof ScenarioSchema>;

/**
 * Schema metadata
 */
export const ScenarioMeta = {
  version: '1.0.0',
  title: 'Video Scenario Schema',
  description: 'Defines the high-level structure of a video scenario with sections and metadata',
} as const;
