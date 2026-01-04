import { describe, test, expect } from 'bun:test'
import { calculateHealthScore, getHealthStatus, generateSuggestions } from '../../src/server/services/health.ts'
import type { HealthMetrics } from '../../src/shared/types.ts'

describe('calculateHealthScore', () => {
  test('returns 100 for perfect configuration', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 3500
    }
    expect(calculateHealthScore(metrics)).toBe(100)
  })

  test('penalizes skills token overflow (>10000) by -10', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 15000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 15500
    }
    expect(calculateHealthScore(metrics)).toBe(90)
  })

  test('penalizes too many unused skills (>3) by -10', () => {
    const metrics: HealthMetrics = {
      skills: { count: 10, totalTokens: 5000, unusedCount: 5 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 5500
    }
    expect(calculateHealthScore(metrics)).toBe(90)
  })

  test('penalizes no skills by -10', () => {
    const metrics: HealthMetrics = {
      skills: { count: 0, totalTokens: 0, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 500
    }
    expect(calculateHealthScore(metrics)).toBe(90)
  })

  test('penalizes memory storage overflow (>30000) by -10', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 35000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 3500
    }
    expect(calculateHealthScore(metrics)).toBe(90)
  })

  test('penalizes memory duplicates by -10', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 2 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 3500
    }
    expect(calculateHealthScore(metrics)).toBe(90)
  })

  test('penalizes no memory by -10', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 0, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 3500
    }
    expect(calculateHealthScore(metrics)).toBe(90)
  })

  test('heavily penalizes rules conflicts by -20', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 5, initialLoadTokens: 500, conflictCount: 2 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 3500
    }
    expect(calculateHealthScore(metrics)).toBe(80)
  })

  test('penalizes no rules by -10', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 0, initialLoadTokens: 0, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 3000
    }
    expect(calculateHealthScore(metrics)).toBe(90)
  })

  test('penalizes too many hooks (>10) by -10', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 15 },
      totalInitialLoadTokens: 3500
    }
    expect(calculateHealthScore(metrics)).toBe(90)
  })

  test('accumulates multiple penalties', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 15000, unusedCount: 5 }, // -10 -10
      memory: { storageTokens: 35000, duplicateCount: 3 },      // -10 -10
      rules: { count: 5, initialLoadTokens: 500, conflictCount: 2 }, // -20
      hooks: { count: 15 },                                     // -10
      totalInitialLoadTokens: 15500
    }
    // 100 - 10 - 10 - 10 - 10 - 20 - 10 = 30
    expect(calculateHealthScore(metrics)).toBe(30)
  })

  test('never goes below 0', () => {
    const metrics: HealthMetrics = {
      skills: { count: 0, totalTokens: 20000, unusedCount: 10 },
      memory: { storageTokens: 50000, duplicateCount: 10 },
      rules: { count: 0, initialLoadTokens: 0, conflictCount: 10 },
      hooks: { count: 100 },
      totalInitialLoadTokens: 20000
    }
    expect(calculateHealthScore(metrics)).toBeGreaterThanOrEqual(0)
  })

  test('never exceeds 100', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 1000, unusedCount: 0 },
      memory: { storageTokens: 500, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 300, conflictCount: 0 },
      hooks: { count: 1 },
      totalInitialLoadTokens: 1300
    }
    expect(calculateHealthScore(metrics)).toBeLessThanOrEqual(100)
  })
})

describe('getHealthStatus', () => {
  test('returns "good" for score >= 80', () => {
    expect(getHealthStatus(100)).toBe('good')
    expect(getHealthStatus(80)).toBe('good')
    expect(getHealthStatus(85)).toBe('good')
  })

  test('returns "warning" for score >= 60 and < 80', () => {
    expect(getHealthStatus(79)).toBe('warning')
    expect(getHealthStatus(60)).toBe('warning')
    expect(getHealthStatus(70)).toBe('warning')
  })

  test('returns "error" for score < 60', () => {
    expect(getHealthStatus(59)).toBe('error')
    expect(getHealthStatus(0)).toBe('error')
    expect(getHealthStatus(30)).toBe('error')
  })
})

describe('generateSuggestions', () => {
  test('suggests reducing skills tokens when > 10000', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 15000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 15500
    }
    const suggestions = generateSuggestions(metrics)
    expect(suggestions.some(s => s.includes('Skills') && (s.includes('token') || s.includes('トークン')))).toBe(true)
  })

  test('suggests cleaning unused skills when > 3', () => {
    const metrics: HealthMetrics = {
      skills: { count: 10, totalTokens: 5000, unusedCount: 5 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 5500
    }
    const suggestions = generateSuggestions(metrics)
    expect(suggestions.some(s => s.includes('unused') || s.includes('使用'))).toBe(true)
  })

  test('suggests resolving rule conflicts when present', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 5, initialLoadTokens: 500, conflictCount: 2 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 3500
    }
    const suggestions = generateSuggestions(metrics)
    expect(suggestions.some(s => s.includes('conflict') || s.includes('コンフリクト'))).toBe(true)
  })

  test('returns empty array for perfect config', () => {
    const metrics: HealthMetrics = {
      skills: { count: 5, totalTokens: 3000, unusedCount: 0 },
      memory: { storageTokens: 2000, duplicateCount: 0 },
      rules: { count: 3, initialLoadTokens: 500, conflictCount: 0 },
      hooks: { count: 2 },
      totalInitialLoadTokens: 3500
    }
    const suggestions = generateSuggestions(metrics)
    expect(suggestions.length).toBe(0)
  })
})
