import { useState, useEffect, useCallback } from 'react'
import type { HealthResponse } from '../../shared/types.ts'
import { fetchHealth } from '../lib/api.ts'

/**
 * Health データを取得するフック
 * @param projectPath - オプションのプロジェクトパス（指定しない場合はアクティブプロジェクト）
 */
export function useHealth(projectPath?: string) {
  const [health, setHealth] = useState<HealthResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchHealth(projectPath)
      setHealth(data)
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Unknown error'))
    } finally {
      setLoading(false)
    }
  }, [projectPath])

  useEffect(() => {
    refresh()
  }, [refresh])

  return { health, loading, error, refresh }
}
