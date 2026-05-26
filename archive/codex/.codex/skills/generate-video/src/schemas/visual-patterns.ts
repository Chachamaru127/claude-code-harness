/**
 * @file visual-patterns.ts
 * @description Auto-generated Zod schema for Visual Patterns Schema
 * @version 1.0.0
 * @generated This file is auto-generated from schemas/visual-patterns.schema.json
 *           All $ref references are resolved during generation.
 *           DO NOT EDIT MANUALLY - run `npm run generate:schemas` instead
 */

import { z } from 'zod';

/**
 * 画像生成パターンのスキーマ。比較図、概念図、フロー図、強調画像の4パターンを定義します。
 */
export const VisualPatternsSchema = z.object({ "type": z.enum(["comparison","concept","flow","highlight"]).describe("画像パターンの種類"), "topic": z.string().min(1).max(200).describe("画像の主題・テーマ"), "style": z.enum(["minimalist","technical","modern","gradient","flat","3d"]).describe("視覚スタイル（オプション）").default("modern"), "color_scheme": z.object({ "primary": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("プライマリカラー（例: #3B82F6）").optional(), "secondary": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("セカンダリカラー（例: #10B981）").optional(), "accent": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("アクセントカラー（例: #F59E0B）").optional(), "background": z.string().regex(new RegExp("^#[0-9A-Fa-f]{6}$")).describe("背景色（例: #1F2937）").default("#1F2937") }).strict().describe("カラースキーム設定").optional(), "comparison": z.object({ "left_side": z.object({ "label": z.string().min(1).max(50).describe("ラベル（例: Before, 悪い例）"), "items": z.array(z.string().min(1).max(100)).min(1).max(5).describe("表示項目リスト"), "icon": z.enum(["x","warning","sad","slow","confused","broken"]).describe("アイコンタイプ（例: x, warning, sad）").optional(), "sentiment": z.enum(["negative","neutral","caution"]).describe("感情・印象").default("negative") }).strict().describe("左側（Before / 悪い例）"), "right_side": z.object({ "label": z.string().min(1).max(50).describe("ラベル（例: After, 良い例）"), "items": z.array(z.string().min(1).max(100)).min(1).max(5).describe("表示項目リスト"), "icon": z.enum(["check","star","happy","fast","clear","solid"]).describe("アイコンタイプ（例: check, star, happy）").optional(), "sentiment": z.enum(["positive","neutral","success"]).describe("感情・印象").default("positive") }).strict().describe("右側（After / 良い例）"), "divider": z.enum(["arrow","vs","line","gradient"]).describe("区切り線の種類").default("arrow") }).strict().describe("comparison（比較図）パターン用の設定").optional(), "concept": z.object({ "elements": z.array(z.object({ "id": z.string().regex(new RegExp("^[a-z0-9_-]+$")).describe("要素の一意なID"), "label": z.string().min(1).max(50).describe("要素のラベル"), "description": z.string().max(200).describe("要素の説明（オプション）").optional(), "level": z.number().int().gte(0).lte(5).describe("階層レベル（0=最上位）").default(0), "parent_id": z.string().regex(new RegExp("^[a-z0-9_-]+$")).describe("親要素のID（階層構造を表現）").optional(), "icon": z.enum(["box","circle","diamond","hexagon","cloud","gear","database","server","user","code"]).describe("アイコンタイプ").optional(), "emphasis": z.enum(["high","medium","low"]).describe("強調度").default("medium") }).strict()).min(2).max(10).describe("概念要素のリスト"), "relationships": z.array(z.object({ "from": z.string().regex(new RegExp("^[a-z0-9_-]+$")).describe("関係の始点となる要素ID"), "to": z.string().regex(new RegExp("^[a-z0-9_-]+$")).describe("関係の終点となる要素ID"), "label": z.string().max(30).describe("関係のラベル（例: 含む、生成、依存）").optional(), "type": z.enum(["hierarchy","flow","dependency","association"]).describe("関係のタイプ").default("association"), "bidirectional": z.boolean().describe("双方向の関係か").default(false) }).strict()).describe("要素間の関係性").optional(), "layout": z.enum(["hierarchy","radial","grid","flow","circular"]).describe("レイアウトタイプ").default("hierarchy") }).strict().describe("concept（概念図）パターン用の設定").optional(), "flow": z.object({ "steps": z.array(z.object({ "id": z.string().regex(new RegExp("^[a-z0-9_-]+$")).describe("ステップの一意なID"), "label": z.string().min(1).max(50).describe("ステップのラベル"), "description": z.string().max(150).describe("ステップの詳細説明").optional(), "order": z.number().int().gte(1).lte(20).describe("ステップの順序（1始まり）").optional(), "type": z.enum(["start","process","decision","end","parallel","subprocess"]).describe("ステップのタイプ").default("process"), "icon": z.enum(["circle","square","diamond","rounded","hexagon"]).describe("アイコンタイプ").optional(), "duration": z.string().max(20).describe("所要時間の目安（例: 2分、即座）").optional() }).strict()).min(2).max(10).describe("フローのステップ"), "direction": z.enum(["horizontal","vertical","zigzag"]).describe("フローの方向").default("horizontal"), "arrow_style": z.enum(["solid","dashed","dotted","thick","animated"]).describe("矢印のスタイル").default("solid"), "show_numbers": z.boolean().describe("ステップ番号を表示するか").default(true) }).strict().describe("flow（フロー図）パターン用の設定").optional(), "highlight": z.object({ "main_text": z.string().min(1).max(100).describe("メインテキスト（強調する内容）"), "sub_text": z.string().max(150).describe("サブテキスト（補足説明）").optional(), "icon": z.enum(["star","check","alert","info","trophy","rocket","fire","bolt","heart","none"]).describe("アイコンタイプ").default("none"), "position": z.enum(["center","top","bottom","left","right"]).describe("テキストの配置").default("center"), "effect": z.enum(["glow","shadow","gradient","outline","none"]).describe("視覚効果").default("glow"), "font_size": z.enum(["small","medium","large","xlarge"]).describe("フォントサイズ").default("large"), "emphasis": z.enum(["high","medium","low"]).describe("強調度").default("high") }).strict().describe("highlight（強調）パターン用の設定").optional(), "dimensions": z.object({ "width": z.number().int().gte(256).lte(2048).describe("幅（ピクセル）").default(1920), "height": z.number().int().gte(256).lte(2048).describe("高さ（ピクセル）").default(1080), "aspect_ratio": z.enum(["16:9","4:3","1:1","9:16"]).describe("アスペクト比").default("16:9") }).strict().describe("画像サイズ設定").optional(), "generation": z.object({ "seed": z.number().int().gte(0).describe("決定性シード値（再現性のため）").optional(), "quality": z.enum(["draft","standard","high"]).describe("画像品質").default("standard"), "retries": z.number().int().gte(0).lte(5).describe("品質不合格時の最大再試行回数").default(3) }).strict().describe("生成設定").optional(), "metadata": z.object({ "scene_id": z.string().describe("関連するシーンID").optional(), "purpose": z.string().max(50).describe("画像の目的（例: intro, demo, cta）").optional(), "tags": z.array(z.string().max(30)).max(10).describe("タグ").optional() }).catchall(z.unknown()).describe("メタデータ（追加情報）").optional() }).strict().and(z.unknown().superRefine((x, ctx) => {
    const schemas = [z.object({ "type": z.literal("comparison").optional() }), z.object({ "type": z.literal("concept").optional() }), z.object({ "type": z.literal("flow").optional() }), z.object({ "type": z.literal("highlight").optional() })];
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
  })).describe("画像生成パターンのスキーマ。比較図、概念図、フロー図、強調画像の4パターンを定義します。")

/**
 * Inferred TypeScript type from Zod schema
 */
export type VisualPatterns = z.infer<typeof VisualPatternsSchema>;

/**
 * Schema metadata
 */
export const VisualPatternsMeta = {
  version: '1.0.0',
  title: 'Visual Patterns Schema',
  description: '画像生成パターンのスキーマ。比較図、概念図、フロー図、強調画像の4パターンを定義します。',
} as const;
