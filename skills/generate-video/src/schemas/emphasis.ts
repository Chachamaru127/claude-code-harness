/**
 * @file emphasis.ts
 * @description Auto-generated Zod schema for Emphasis Schema
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/emphasis.schema.json
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * 強調表現のスキーマ。テキスト強調、効果音、カラー、配置を定義します。
 */
import { z } from "zod"

export const Emphasis = z.object({ "level": z.enum(["high","medium","low"]).describe("強調レベル"), "text": z.array(z.object({ "content": z.string().describe("強調するテキスト内容"), "start_frame": z.number().int().gte(0).describe("強調開始フレーム（シーン内での相対位置）").optional(), "duration_frames": z.number().int().gte(1).describe("強調表示の長さ（フレーム数）").default(30), "style": z.enum(["bold","glitch","underline","highlight","glow"]).describe("テキストスタイル").default("bold") }).strict()).describe("強調するテキスト要素（キーワード・フレーズ）").default([]), "sound": z.object({ "type": z.enum(["none","pop","whoosh","chime","ding"]).describe("効果音の種類").default("none"), "volume": z.number().gte(0).lte(1).describe("音量（0.0-1.0）").default(0.5), "timing": z.enum(["start","end","peak"]).describe("効果音のタイミング").default("start"), "trigger_frame": z.number().int().gte(0).describe("効果音発動フレーム（シーン内での相対位置）").default(0) }).strict().describe("効果音設定").optional(), "color": z.object({ "primary": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("プライマリカラー（HEX形式）").default("#00F5FF"), "secondary": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("セカンダリカラー（HEX形式、グラデーション用）").optional(), "glow": z.boolean().describe("グロー効果を適用するか").default(true), "glowIntensity": z.number().gte(0).lte(100).describe("グロー強度（ぼかし半径、ピクセル）").default(20) }).strict().describe("強調カラー設定").optional(), "position": z.object({ "alignment": z.enum(["center","top","bottom","left","right","topLeft","topRight","bottomLeft","bottomRight"]).describe("配置位置").default("center"), "offset": z.object({ "x": z.number().describe("X軸オフセット").default(0), "y": z.number().describe("Y軸オフセット").default(0) }).strict().describe("配置オフセット（ピクセル）").optional(), "padding": z.number().gte(0).describe("画面端からのパディング（ピクセル）").default(40) }).strict().describe("強調要素の配置設定").optional(), "animation": z.object({ "entry": z.enum(["none","fadeIn","slideIn","zoomIn","bounce"]).describe("登場アニメーション").default("fadeIn"), "exit": z.enum(["none","fadeOut","slideOut","zoomOut"]).describe("退場アニメーション").default("fadeOut"), "duration_frames": z.number().int().gte(1).lte(60).describe("アニメーション長さ（フレーム数）").default(15), "pulse": z.boolean().describe("パルス効果（点滅・拡縮）を有効にするか").default(false), "pulseSpeed": z.number().gte(0.01).lte(1).describe("パルス速度（1フレームあたりの周期進行度）").default(0.1) }).strict().describe("強調表示のアニメーション設定").optional(), "background": z.object({ "enabled": z.boolean().describe("背景を表示するか").default(false), "color": z.string().describe("背景カラー（HEX形式またはRGBA）").default("rgba(0, 0, 0, 0.8)"), "borderRadius": z.number().gte(0).describe("角丸の半径（ピクセル）").default(8), "padding": z.object({ "top": z.number().gte(0).default(16), "right": z.number().gte(0).default(32), "bottom": z.number().gte(0).default(16), "left": z.number().gte(0).default(32) }).strict().describe("背景内のパディング（ピクセル）").optional(), "border": z.object({ "enabled": z.boolean().default(false), "width": z.number().gte(0).default(2), "color": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("ボーダーカラー（HEX形式）").default("#00F5FF") }).strict().describe("ボーダー設定").optional() }).strict().describe("強調要素の背景設定（ボックス表示など）").optional(), "typography": z.object({ "fontSize": z.number().gte(12).lte(200).describe("フォントサイズ（ピクセル）").default(48), "fontWeight": z.union([z.literal(100), z.literal(200), z.literal(300), z.literal(400), z.literal(500), z.literal(600), z.literal(700), z.literal(800), z.literal(900), z.literal("normal"), z.literal("bold")]).describe("フォントの太さ").default(700), "fontFamily": z.string().describe("フォントファミリー").default("sans-serif"), "lineHeight": z.number().gte(0.5).lte(3).describe("行の高さ（倍率）").default(1.5), "letterSpacing": z.number().describe("文字間隔（ピクセル）").default(0), "textTransform": z.enum(["none","uppercase","lowercase","capitalize"]).describe("テキスト変換").default("none") }).strict().describe("タイポグラフィ設定").optional() }).strict().describe("強調表現のスキーマ。テキスト強調、効果音、カラー、配置を定義します。")


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
