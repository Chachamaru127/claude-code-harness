/**
 * 共通ローディング状態コンポーネント
 */

interface LoadingStateProps {
  message?: string
}

export function LoadingState({ message = '読み込み中...' }: LoadingStateProps) {
  return (
    <div className="page-container">
      <div className="flex items-center gap-4">
        <div className="spinner" aria-hidden="true" />
        <span role="status" aria-live="polite">{message}</span>
      </div>
    </div>
  )
}
