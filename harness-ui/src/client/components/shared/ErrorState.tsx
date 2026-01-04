/**
 * 共通エラー状態コンポーネント
 */

interface ErrorStateProps {
  message?: string
  onRetry?: () => void
}

export function ErrorState({
  message = 'データの取得に失敗しました',
  onRetry
}: ErrorStateProps) {
  return (
    <div className="page-container">
      <div className="health-error" role="alert">
        <span>{message}</span>
        {onRetry && (
          <button
            onClick={onRetry}
            className="error-retry-btn"
            style={{
              marginLeft: '1rem',
              padding: '0.25rem 0.5rem',
              border: '1px solid currentColor',
              borderRadius: '0.25rem',
              background: 'transparent',
              cursor: 'pointer'
            }}
          >
            再試行
          </button>
        )}
      </div>
    </div>
  )
}
