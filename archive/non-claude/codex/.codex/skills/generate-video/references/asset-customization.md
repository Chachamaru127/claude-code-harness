# Asset Customization Guide

ユーザーカスタムアセット（背景、効果音、フォント、画像）の上書き方法とベストプラクティス。

---

## 概要

動画生成で使用するアセットは以下の優先順位で読み込まれます：

```
1. ユーザーアセット (~/.harness/video/assets/)    ← 最優先
2. スキルデフォルト (skills/generate-video/assets/) ← フォールバック
3. ビルトインデフォルト (ハードコード)              ← 最終手段
```

この仕組みにより、スキル本体を変更せずに自分好みのアセットを使用できます。

---

## ディレクトリ構造

### ユーザーアセットディレクトリ

```
~/.harness/video/assets/
├── README.md                    # 使い方ガイド（自動生成）
├── backgrounds/
│   ├── backgrounds.json         # カスタム背景定義
│   └── my-custom-bg.png         # カスタム背景画像（オプション）
├── sounds/
│   ├── sounds.json              # カスタム効果音定義
│   ├── impact.mp3               # 高強調音
│   ├── pop.mp3                  # 中強調音
│   ├── transition.mp3           # 場面転換音
│   └── subtle.mp3               # 低強調音
├── fonts/
│   ├── MyBrand-Bold.ttf
│   └── MyBrand-Regular.ttf
└── images/
    ├── logo.png
    └── icon.png
```

### 初期化

ユーザーアセットディレクトリを作成:

```bash
node scripts/load-assets.js init
```

または手動で作成:

```bash
mkdir -p ~/.harness/video/assets/{backgrounds,sounds,fonts,images}
```

---

## カスタマイズ方法

### 1. 背景のカスタマイズ

#### 手順

1. **デフォルト設定をコピー**:

```bash
cp skills/generate-video/assets/backgrounds/backgrounds.json \
   ~/.harness/video/assets/backgrounds/
```

2. **設定を編集**:

```json
{
  "version": "1.0.0",
  "backgrounds": [
    {
      "id": "my-brand",
      "name": "My Brand Background",
      "description": "Company brand colors",
      "type": "gradient",
      "colors": {
        "primary": "#1e3a8a",
        "secondary": "#3b82f6",
        "accent": "#60a5fa"
      },
      "gradient": {
        "type": "linear",
        "angle": 135,
        "stops": [
          { "color": "#1e3a8a", "position": 0 },
          { "color": "#3b82f6", "position": 50 },
          { "color": "#60a5fa", "position": 100 }
        ]
      },
      "usage": {
        "scenes": ["intro", "cta"],
        "recommended_for": "Brand-focused content"
      }
    }
  ]
}
```

3. **動画生成で使用**:

```json
{
  "scene": {
    "background": "my-brand"
  }
}
```

#### 背景タイプ

| Type | Description | Fields |
|------|-------------|--------|
| `gradient` | グラデーション背景 | `colors`, `gradient` |
| `pattern` | パターン背景（グリッド等） | `colors`, `gradient`, `pattern` |
| `solid` | 単色背景 | `colors.primary` |
| `image` | 画像背景 | `file` (path to image) |

#### グラデーションタイプ

```json
// Linear gradient
"gradient": {
  "type": "linear",
  "angle": 135,
  "stops": [...]
}

// Radial gradient
"gradient": {
  "type": "radial",
  "stops": [...]
}
```

---

### 2. 効果音のカスタマイズ

#### 手順

1. **デフォルト設定をコピー**:

```bash
cp skills/generate-video/assets/sounds/sounds.json \
   ~/.harness/video/assets/sounds/
```

2. **効果音ファイルを配置**:

```bash
# FreeSoundからダウンロード（CC0ライセンス推奨）
cp ~/Downloads/my-impact.mp3 ~/.harness/video/assets/sounds/impact.mp3
cp ~/Downloads/my-pop.mp3 ~/.harness/video/assets/sounds/pop.mp3
```

3. **設定を編集**:

```json
{
  "version": "1.0.0",
  "sounds": [
    {
      "id": "impact",
      "name": "Custom Impact",
      "type": "effect",
      "category": "emphasis",
      "emphasis_level": "high",
      "file": {
        "placeholder": "impact.mp3",
        "expected_duration": 0.5,
        "format": "mp3"
      },
      "volume": {
        "default": 0.7,
        "with_narration": 0.4,
        "with_bgm": 0.6
      }
    }
  ]
}
```

#### 推奨形式

| Format | Sample Rate | Bit Depth | Notes |
|--------|-------------|-----------|-------|
| MP3 | 44100 Hz | 16-bit | 推奨（互換性高） |
| WAV | 44100 Hz | 16-bit | 高品質（ファイルサイズ大） |
| OGG | 44100 Hz | - | 軽量（ブラウザ互換性注意） |

#### ボリューム推奨値

| Context | Volume Range | Notes |
|---------|--------------|-------|
| ナレーションあり | 0.15 - 0.4 | 音声を邪魔しない |
| BGMあり | 0.25 - 0.6 | BGMをダッキング |
| 音声なし | 0.3 - 1.0 | フル音量OK |

---

### 3. フォントのカスタマイズ

#### 手順

1. **フォントファイルを配置**:

```bash
cp ~/Downloads/MyFont-Bold.ttf ~/.harness/video/assets/fonts/
cp ~/Downloads/MyFont-Regular.ttf ~/.harness/video/assets/fonts/
```

2. **シーン設定で参照**:

```json
{
  "scene": {
    "text": {
      "content": "My Message",
      "font": {
        "family": "MyFont",
        "weight": "bold",
        "file": "~/.harness/video/assets/fonts/MyFont-Bold.ttf"
      }
    }
  }
}
```

#### Remotionでの使用

```typescript
import { loadFont } from '@remotion/google-fonts/Inter';

// カスタムフォント読み込み
const fontFamily = loadFont({
  src: '~/.harness/video/assets/fonts/MyFont-Bold.ttf',
  fontFamily: 'MyFont',
  fontWeight: 'bold',
});
```

#### 推奨形式

| Format | Web Safe | Notes |
|--------|----------|-------|
| TTF | ✅ Yes | 推奨（最も互換性が高い） |
| OTF | ✅ Yes | OpenType機能が使える |
| WOFF/WOFF2 | ✅ Yes | Web最適化（軽量） |

---

### 4. 画像のカスタマイズ

#### 手順

1. **画像ファイルを配置**:

```bash
cp ~/Downloads/logo.png ~/.harness/video/assets/images/
cp ~/Downloads/icon.png ~/.harness/video/assets/images/
```

2. **シーン設定で参照**:

```json
{
  "scene": {
    "image": {
      "src": "~/.harness/video/assets/images/logo.png",
      "width": 200,
      "height": 100
    }
  }
}
```

#### 推奨形式

| Format | Use Case | Notes |
|--------|----------|-------|
| PNG | ロゴ、アイコン | 透過対応 |
| JPG | 写真、背景 | 圧縮率高 |
| SVG | ベクター図形 | 拡大しても綺麗 |
| WebP | モダン環境 | 軽量高品質 |

#### サイズガイドライン

| Asset Type | Recommended Size | Max Size |
|------------|------------------|----------|
| Logo | 500x500 px | 1000x1000 px |
| Icon | 128x128 px | 512x512 px |
| Background | 1920x1080 px | 3840x2160 px |
| Screenshot | 1920x1080 px | 2560x1440 px |

---

## 優先順位の詳細

### 読み込み順序

`scripts/load-assets.js` は以下の順序でアセットを検索:

```javascript
// 1. ユーザーアセット
const userPath = '~/.harness/video/assets/{category}/{file}';
if (exists(userPath)) return userPath;

// 2. スキルデフォルト
const skillPath = 'skills/generate-video/assets/{category}/{file}';
if (exists(skillPath)) return skillPath;

// 3. ビルトインデフォルト
return getBuiltInDefault();
```

### 部分上書き

一部のアセットだけ上書き可能:

```bash
# 背景だけカスタマイズ（効果音はデフォルト使用）
cp my-backgrounds.json ~/.harness/video/assets/backgrounds/backgrounds.json
```

### JSON内の部分上書き

```json
// ~/.harness/video/assets/backgrounds/backgrounds.json
{
  "version": "1.0.0",
  "backgrounds": [
    {
      "id": "my-brand",
      "name": "My Brand"
      // ... カスタム設定
    }
    // "neutral", "highlight" 等は省略 → デフォルトから読み込まれる
  ]
}
```

**注意**: 同じ `id` がある場合、ユーザー設定が優先されます。

---

## 動作確認

### テストコマンド

```bash
# アセット読み込みテスト
node scripts/load-assets.js test

# 背景設定表示
node scripts/load-assets.js backgrounds

# 効果音設定表示
node scripts/load-assets.js sounds

# 検索パス表示
node scripts/load-assets.js paths
```

### 期待される出力

```
🧪 Testing asset loader...

🎨 Loading backgrounds...
  ✅ Loaded user backgrounds from: ~/.harness/video/assets/backgrounds/backgrounds.json

🔊 Loading sounds...
  ✅ Loaded skill sounds from: skills/generate-video/assets/sounds/sounds.json

📂 Asset paths:
{
  "user": "~/.harness/video/assets",
  "skill": "skills/generate-video/assets"
}
```

---

## トラブルシューティング

### 問題: アセットが読み込まれない

**原因**: ファイルパスが間違っている

**解決策**:
```bash
# パスを確認
node scripts/load-assets.js paths

# ファイルの存在確認
ls -la ~/.harness/video/assets/backgrounds/
```

### 問題: JSON解析エラー

**原因**: JSON形式が不正

**解決策**:
```bash
# JSONの妥当性チェック
cat ~/.harness/video/assets/backgrounds/backgrounds.json | jq .

# エラーメッセージを確認
node scripts/load-assets.js test
```

### 問題: 効果音が再生されない

**原因**: ファイル形式が非対応

**解決策**:
```bash
# MP3に変換
ffmpeg -i input.wav -codec:a libmp3lame -b:a 192k output.mp3

# ファイル情報確認
ffprobe output.mp3
```

### 問題: フォントが表示されない

**原因**: フォントファイルパスが解決できない

**解決策**:
```typescript
// 絶対パスを使用
const fontPath = path.join(os.homedir(), '.harness/video/assets/fonts/MyFont.ttf');
```

---

## ベストプラクティス

### 1. バージョン管理

カスタムアセットをGit管理したい場合:

```bash
# プロジェクトルートに配置
project-root/
├── .video-assets/
│   ├── backgrounds/
│   ├── sounds/
│   └── fonts/
└── .gitignore  # .harness/ は除外

# シンボリックリンク作成
ln -s $(pwd)/.video-assets ~/.harness/video/assets
```

### 2. チーム共有

チームで共通のアセットを使用:

```bash
# 共有リポジトリ
git clone https://github.com/company/video-assets.git ~/.harness/video/assets
```

### 3. プロジェクト別アセット

プロジェクトごとに異なるアセット:

```bash
# 環境変数で切り替え
export VIDEO_ASSETS_DIR=/path/to/project-specific/assets

# load-assets.js で環境変数を参照
const assetsDir = process.env.VIDEO_ASSETS_DIR || defaultPath;
```

### 4. ライセンス管理

```
~/.harness/video/assets/
└── LICENSES.md    # 各アセットのライセンス情報
```

```markdown
# Asset Licenses

## Sounds

- impact.mp3: CC0, from freesound.org/s/12345
- pop.mp3: CC BY 3.0, by Author Name

## Fonts

- MyFont-Bold.ttf: SIL Open Font License
```

---

## サンプル集

### ブランドカラー背景

```json
{
  "id": "brand-primary",
  "name": "Brand Primary",
  "type": "gradient",
  "colors": {
    "primary": "#your-brand-color",
    "secondary": "#your-secondary-color"
  },
  "gradient": {
    "type": "linear",
    "angle": 135,
    "stops": [
      { "color": "#your-brand-color", "position": 0 },
      { "color": "#your-secondary-color", "position": 100 }
    ]
  },
  "usage": {
    "scenes": ["intro", "outro", "cta"]
  }
}
```

### カスタム効果音セット

```json
{
  "id": "whoosh",
  "name": "Whoosh Transition",
  "type": "effect",
  "category": "transition",
  "file": {
    "placeholder": "whoosh.mp3",
    "expected_duration": 0.6
  },
  "volume": {
    "default": 0.5,
    "with_narration": 0.3
  },
  "timing": {
    "offset_before_visual": -0.1
  }
}
```

### 企業ロゴ

```json
{
  "scene": {
    "image": {
      "src": "~/.harness/video/assets/images/company-logo.png",
      "width": 300,
      "height": 150,
      "position": "top-right"
    }
  }
}
```

---

## 参照

- **Asset Loader**: `scripts/load-assets.js`
- **Default Backgrounds**: `assets/backgrounds/backgrounds.json`
- **Default Sounds**: `assets/sounds/sounds.json`
- **BackgroundLayer Component**: `remotion/src/components/BackgroundLayer.tsx`
- **Plans.md**: Phase 7 - Asset Foundation

---

## 更新履歴

- **2026-02-02**: 初版作成（Phase 7実装）
