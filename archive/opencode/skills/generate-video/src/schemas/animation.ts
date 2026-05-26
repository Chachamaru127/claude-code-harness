/**
 * @file animation.ts
 * @description Auto-generated Zod schema for Animation Schema
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/animation.schema.json
 *           All $ref references are resolved during generation.
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * アニメーション設定のスキーマ。トランジション、イージング、スプリング物理演算パラメータを定義します。
 */
export const AnimationSchema = z.object({ "type": z.enum(["fade","slide_in","zoom","cut","spring","rotate","scale"]).describe("アニメーションの種類"), "duration_ms": z.number().int().gte(0).lte(10000).describe("アニメーションの長さ（ミリ秒）"), "easing": z.enum(["linear","easeIn","easeOut","easeInOut","easeInQuad","easeOutQuad","easeInOutQuad","easeInCubic","easeOutCubic","easeInOutCubic"]).describe("イージング関数（springタイプの場合は無視される）").default("easeInOut"), "spring": z.object({ "damping": z.number().gte(1).lte(500).describe("ダンピング（減衰係数）。値が大きいほど早く止まる").default(200), "stiffness": z.number().gte(1).lte(500).describe("スティフネス（バネの硬さ）。値が大きいほど反発が強い").default(100), "mass": z.number().gte(0.1).lte(10).describe("質量。値が大きいほど動きが重くなる").default(1), "overshoot_clamping": z.boolean().describe("オーバーシュート（行き過ぎ）を抑制するか").default(false) }).strict().describe("スプリング物理演算パラメータ（typeがspringの場合のみ適用）").optional(), "delay_ms": z.number().int().gte(0).describe("アニメーション開始前の遅延（ミリ秒）").default(0), "from": z.object({ "opacity": z.number().gte(0).lte(1).optional(), "x": z.number().describe("X座標オフセット（ピクセル）").optional(), "y": z.number().describe("Y座標オフセット（ピクセル）").optional(), "scale": z.number().gte(0).describe("スケール値").optional(), "rotate": z.number().describe("回転角度（度数法）").optional() }).strict().describe("アニメーション開始時の値").optional(), "to": z.object({ "opacity": z.number().gte(0).lte(1).optional(), "x": z.number().describe("X座標オフセット（ピクセル）").optional(), "y": z.number().describe("Y座標オフセット（ピクセル）").optional(), "scale": z.number().gte(0).describe("スケール値").optional(), "rotate": z.number().describe("回転角度（度数法）").optional() }).strict().describe("アニメーション終了時の値").optional(), "interpolate": z.object({ "input_range": z.array(z.number()).min(2).describe("入力範囲（フレーム数の配列）").optional(), "output_range": z.array(z.number()).min(2).describe("出力範囲（値の配列）").optional(), "extrapolate_left": z.enum(["clamp","extend","identity"]).describe("範囲外（左）の補外方法").default("clamp"), "extrapolate_right": z.enum(["clamp","extend","identity"]).describe("範囲外（右）の補外方法").default("clamp") }).strict().describe("Remotion interpolate関数の詳細設定").optional(), "loop": z.object({ "enabled": z.boolean().describe("ループを有効にするか").default(false), "count": z.number().int().gte(0).describe("ループ回数（0で無限ループ）").default(0), "reverse": z.boolean().describe("往復ループ（前進→後退）にするか").default(false) }).strict().describe("ループ設定（オプション）").optional() }).strict().describe("アニメーション設定のスキーマ。トランジション、イージング、スプリング物理演算パラメータを定義します。")

/**
 * Inferred TypeScript type from Zod schema
 */
export type Animation = z.infer<typeof AnimationSchema>;

/**
 * Schema metadata
 */
export const AnimationMeta = {
  version: '1.0.0',
  title: 'Animation Schema',
  description: 'アニメーション設定のスキーマ。トランジション、イージング、スプリング物理演算パラメータを定義します。',
} as const;
