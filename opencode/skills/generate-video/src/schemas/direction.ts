/**
 * @file direction.ts
 * @description Auto-generated Zod schema for Direction Schema
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/direction.schema.json
 *           All $ref references are resolved during generation.
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * 演出システムのスキーマ。シーンごとの演出パラメータ（トランジション、強調、背景、タイミング）を定義します。
 */
export const DirectionSchema = z.object({ "scene_id": z.string().regex(new RegExp("^[a-zA-Z0-9_-]+$")).describe("対象シーンのID（シナリオ内のシーンと一致する必要がある）"), "transition": z.object({ "type": z.enum(["fade","slide_in","zoom","cut"]).describe("トランジションの種類"), "duration_ms": z.number().int().gte(0).lte(2000).describe("トランジションの長さ（ミリ秒）").default(500), "easing": z.enum(["linear","easeIn","easeOut","easeInOut"]).describe("イージング関数").default("easeInOut"), "direction": z.enum(["left","right","top","bottom"]).describe("スライドの方向（slide_inの場合のみ）").default("right") }).strict().describe("このシーンへのトランジション設定"), "emphasis": z.object({ "level": z.enum(["high","medium","low"]).describe("強調レベル"), "text": z.array(z.string()).describe("強調するテキスト要素（キーワード・フレーズ）").default([]), "sound": z.enum(["none","pop","whoosh","chime","ding"]).describe("効果音の種類").default("none"), "color": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("強調カラー（HEX形式）").default("#00F5FF"), "position": z.enum(["center","top","bottom","left","right"]).describe("強調要素の配置").default("center") }).strict().describe("シーン内での強調表現"), "background": z.object({ "type": z.enum(["cyberpunk","corporate","minimal","gradient","particles"]).describe("背景の種類"), "primary_color": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("プライマリカラー（HEX形式）").optional(), "secondary_color": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("セカンダリカラー（HEX形式）").optional(), "opacity": z.number().gte(0).lte(1).describe("背景の不透明度").default(1), "blur": z.boolean().describe("背景にブラーを適用するか").default(false) }).strict().describe("背景設定"), "timing": z.object({ "delay_before_ms": z.number().int().gte(0).describe("シーン開始前の待機時間（ミリ秒）").default(0), "delay_after_ms": z.number().int().gte(0).describe("シーン終了後の待機時間（ミリ秒）").default(0), "audio_start_offset_ms": z.number().int().describe("音声開始オフセット（ミリ秒、正=遅延、負=早める）").default(1000) }).strict().describe("シーン内のタイミング調整") }).strict().describe("演出システムのスキーマ。シーンごとの演出パラメータ（トランジション、強調、背景、タイミング）を定義します。")

/**
 * Inferred TypeScript type from Zod schema
 */
export type Direction = z.infer<typeof DirectionSchema>;

/**
 * Schema metadata
 */
export const DirectionMeta = {
  version: '1.0.0',
  title: 'Direction Schema',
  description: '演出システムのスキーマ。シーンごとの演出パラメータ（トランジション、強調、背景、タイミング）を定義します。',
} as const;
