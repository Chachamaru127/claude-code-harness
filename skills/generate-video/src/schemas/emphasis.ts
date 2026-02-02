/**
 * @file emphasis.ts
 * @description Auto-generated Zod schema for Emphasis Schema
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/emphasis.schema.json
 *           All $ref references are resolved during generation.
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * 強調表現のスキーマ。テキスト強調、効果音、カラー、配置を定義します。
 */
export const EmphasisSchema = z.object({ "level": z.enum(["high","medium","low"]).describe("強調レベル"), "text": z.array(z.object({ "content": z.string().describe("強調するテキスト内容"), "start_ms": z.number().int().gte(0).describe("強調開始時刻（シーン内での相対位置、ミリ秒）").optional(), "duration_ms": z.number().int().gte(1).describe("強調表示の長さ（ミリ秒）").default(1000), "style": z.enum(["bold","glitch","underline","highlight","glow"]).describe("テキストスタイル").default("bold") }).strict()).describe("強調するテキスト要素（キーワード・フレーズ）").default([]), "sound": z.object({ "type": z.enum(["none","pop","whoosh","chime","ding"]).describe("効果音の種類").default("none"), "volume": z.number().gte(0).lte(1).describe("音量（0.0-1.0）").default(0.5), "timing": z.enum(["start","end","peak"]).describe("効果音のタイミング").default("start"), "trigger_ms": z.number().int().gte(0).describe("効果音発動時刻（シーン内での相対位置、ミリ秒）").default(0) }).strict().describe("効果音設定").optional(), "color": z.object({ "primary": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("プライマリカラー（HEX形式）").default("#00F5FF"), "secondary": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("セカンダリカラー（HEX形式、グラデーション用）").optional(), "glow": z.boolean().describe("グロー効果を適用するか").default(true), "glow_intensity": z.number().gte(0).lte(100).describe("グロー強度（ぼかし半径、ピクセル）").default(20) }).strict().describe("強調カラー設定").optional(), "position": z.object({ "alignment": z.enum(["center","top","bottom","left","right","top_left","top_right","bottom_left","bottom_right"]).describe("配置位置").default("center"), "offset": z.object({ "x": z.number().describe("X軸オフセット").default(0), "y": z.number().describe("Y軸オフセット").default(0) }).strict().describe("配置オフセット（ピクセル）").optional(), "padding": z.number().gte(0).describe("画面端からのパディング（ピクセル）").default(40) }).strict().describe("強調要素の配置設定").optional(), "animation": z.object({ "entry": z.enum(["none","fade_in","slide_in","zoom_in","bounce"]).describe("登場アニメーション").default("fade_in"), "exit": z.enum(["none","fade_out","slide_out","zoom_out"]).describe("退場アニメーション").default("fade_out"), "duration_ms": z.number().int().gte(1).lte(2000).describe("アニメーション長さ（ミリ秒）").default(500), "pulse": z.boolean().describe("パルス効果（点滅・拡縮）を有効にするか").default(false), "pulse_speed": z.number().gte(0.1).lte(10).describe("パルス速度（1秒あたりのサイクル数）").default(1) }).strict().describe("強調表示のアニメーション設定").optional(), "background": z.object({ "enabled": z.boolean().describe("背景を表示するか").default(false), "color": z.string().describe("背景カラー（HEX形式またはRGBA）").default("rgba(0, 0, 0, 0.8)"), "border_radius": z.number().gte(0).describe("角丸の半径（ピクセル）").default(8), "padding": z.object({ "top": z.number().gte(0).default(16), "right": z.number().gte(0).default(32), "bottom": z.number().gte(0).default(16), "left": z.number().gte(0).default(32) }).strict().describe("背景内のパディング（ピクセル）").optional(), "border": z.object({ "enabled": z.boolean().default(false), "width": z.number().gte(0).default(2), "color": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("ボーダーカラー（HEX形式）").default("#00F5FF") }).strict().describe("ボーダー設定").optional() }).strict().describe("強調要素の背景設定（ボックス表示など）").optional(), "typography": z.object({ "font_size": z.number().gte(12).lte(200).describe("フォントサイズ（ピクセル）").default(48), "font_weight": z.union([z.literal(100), z.literal(200), z.literal(300), z.literal(400), z.literal(500), z.literal(600), z.literal(700), z.literal(800), z.literal(900), z.literal("normal"), z.literal("bold")]).describe("フォントの太さ").default(700), "font_family": z.string().describe("フォントファミリー").default("sans-serif"), "line_height": z.number().gte(0.5).lte(3).describe("行の高さ（倍率）").default(1.5), "letter_spacing": z.number().describe("文字間隔（ピクセル）").default(0), "text_transform": z.enum(["none","uppercase","lowercase","capitalize"]).describe("テキスト変換").default("none") }).strict().describe("タイポグラフィ設定").optional() }).strict().describe("強調表現のスキーマ。テキスト強調、効果音、カラー、配置を定義します。")

/**
 * Inferred TypeScript type from Zod schema
 */
export type Emphasis = z.infer<typeof EmphasisSchema>;

/**
 * Schema metadata
 */
export const EmphasisMeta = {
  version: '1.0.0',
  title: 'Emphasis Schema',
  description: '強調表現のスキーマ。テキスト強調、効果音、カラー、配置を定義します。',
} as const;
