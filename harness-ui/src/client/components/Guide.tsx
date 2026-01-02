export function Guide() {
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">VibeCoder ガイド</h1>

      <div className="card">
        <h2 className="text-xl font-semibold mb-4">Harness UI へようこそ</h2>
        <p className="text-muted-foreground mb-4">
          Harness UI は Claude Code の設定を視覚的に管理するためのツールです。
          技術的な知識がなくても、効率的に Claude Code を活用できます。
        </p>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="card">
          <h3 className="font-semibold mb-2">📊 Dashboard</h3>
          <p className="text-sm text-muted-foreground">
            プロジェクトの健康スコアとタスクボードを確認できます。
            スコアが低い場合は、提案に従って設定を改善しましょう。
          </p>
        </div>

        <div className="card">
          <h3 className="font-semibold mb-2">⚡ Skills</h3>
          <p className="text-sm text-muted-foreground">
            利用可能な Skills の一覧を確認できます。
            未使用の Skills は削除してトークン数を節約しましょう。
          </p>
        </div>

        <div className="card">
          <h3 className="font-semibold mb-2">🧠 Memory</h3>
          <p className="text-sm text-muted-foreground">
            Memory ファイルのトークン分布を確認できます。
            重複があればマージを検討してください。
          </p>
        </div>

        <div className="card">
          <h3 className="font-semibold mb-2">📜 Rules</h3>
          <p className="text-sm text-muted-foreground">
            プロジェクト固有のルールを確認できます。
            コンフリクトがあれば解消してください。
          </p>
        </div>

        <div className="card">
          <h3 className="font-semibold mb-2">💡 Insights</h3>
          <p className="text-sm text-muted-foreground">
            AI が設定を分析し、最適化提案を生成します。
            生成されたコマンドをコピーして実行してください。
          </p>
        </div>

        <div className="card">
          <h3 className="font-semibold mb-2">⚙️ Settings</h3>
          <p className="text-sm text-muted-foreground">
            表示設定やシステムステータスを確認できます。
          </p>
        </div>
      </div>

      <div className="card">
        <h2 className="text-xl font-semibold mb-4">よくある質問</h2>

        <div className="space-y-4">
          <div>
            <h4 className="font-medium">Q: 健康スコアが低いのはなぜ？</h4>
            <p className="text-sm text-muted-foreground">
              A: Skills のトークン数が多すぎる、未使用の Skills がある、
              Memory に重複がある、Rules にコンフリクトがある、などが原因です。
              Dashboard の改善提案を参考にしてください。
            </p>
          </div>

          <div>
            <h4 className="font-medium">Q: AI Insights のコストは？</h4>
            <p className="text-sm text-muted-foreground">
              A: AI Insights はあなたの Claude サブスクリプションを使用します。
              追加の API コストはかかりません。
            </p>
          </div>

          <div>
            <h4 className="font-medium">Q: Plans.md が見つからない？</h4>
            <p className="text-sm text-muted-foreground">
              A: プロジェクトルートまたは .claude/ ディレクトリに Plans.md を作成してください。
              ## Plan、## Work、## Review、## Done のセクションを含めてください。
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
