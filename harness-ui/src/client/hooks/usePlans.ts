import { useState, useEffect, useCallback } from 'react'
import type { KanbanResponse, WorkflowMode } from '../../shared/types.ts'
import { fetchPlans } from '../lib/api.ts'

/**
 * Plans データを取得するフック
 * @param mode - ワークフローモード（solo または 2agent）
 * @param projectPath - オプションのプロジェクトパス（指定しない場合はアクティブプロジェクト）
 */
export function usePlans(mode: WorkflowMode = 'solo', projectPath?: string) {
  const [plans, setPlans] = useState<KanbanResponse | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  const refresh = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchPlans(mode, projectPath)
      setPlans(data)
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Unknown error'))
    } finally {
      setLoading(false)
    }
  }, [mode, projectPath])

  useEffect(() => {
    refresh()
  }, [refresh])

  return { plans, loading, error, refresh }
}
