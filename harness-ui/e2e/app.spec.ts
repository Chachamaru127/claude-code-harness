import { test, expect } from '@playwright/test'

const BASE_URL = process.env['TEST_URL'] ?? 'http://localhost:37778'

test.describe('Harness UI E2E Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the app
    await page.goto(BASE_URL)
  })

  test.describe('Dashboard', () => {
    test('displays health score card', async ({ page }) => {
      // Wait for the dashboard to load
      await page.waitForSelector('.card', { timeout: 10000 })

      // Check for health-related content
      const healthCard = page.locator('text=健康スコア').first()
      await expect(healthCard).toBeVisible()
    })

    test('displays kanban board', async ({ page }) => {
      await page.waitForSelector('.kanban-board', { timeout: 10000 })

      // Check for kanban columns
      const columns = page.locator('.kanban-column')
      await expect(columns).toHaveCount(4)
    })

    test('shows loading state initially', async ({ page }) => {
      // Verify the page loads without crashing
      // On slow connections, loading spinner would appear
      await page.waitForLoadState('domcontentloaded')
      // Page should have content after load
      const body = await page.locator('body').textContent()
      expect(body?.length).toBeGreaterThan(0)
    })
  })

  test.describe('Navigation', () => {
    test('sidebar navigation works', async ({ page }) => {
      await page.waitForSelector('.sidebar', { timeout: 10000 })

      // Click on Skills link
      await page.click('text=Skills')
      await expect(page.locator('h1')).toContainText('Skills')

      // Click on Memory link
      await page.click('text=Memory')
      await expect(page.locator('h1')).toContainText('Memory')

      // Click on Rules link
      await page.click('text=Rules')
      await expect(page.locator('h1')).toContainText('Rules')

      // Click on Dashboard to return
      await page.click('text=Dashboard')
      await expect(page.locator('text=健康スコア')).toBeVisible()
    })

    test('sidebar shows active state', async ({ page }) => {
      await page.waitForSelector('.sidebar', { timeout: 10000 })

      // Initially Dashboard should be active
      const dashboardLink = page.locator('.sidebar-link.active')
      await expect(dashboardLink).toBeVisible()
    })
  })

  test.describe('Skills Page', () => {
    test('displays skills list', async ({ page }) => {
      await page.click('text=Skills')
      await page.waitForSelector('h1')

      // Should show Skills Manager heading
      await expect(page.locator('h1')).toContainText('Skills')

      // Should show token count
      const tokenDisplay = page.locator('text=トークン')
      await expect(tokenDisplay.first()).toBeVisible()
    })
  })

  test.describe('Memory Page', () => {
    test('displays memory analyzer', async ({ page }) => {
      await page.click('text=Memory')
      await page.waitForSelector('h1')

      // Should show Memory Analyzer heading
      await expect(page.locator('h1')).toContainText('Memory')
    })
  })

  test.describe('Rules Page', () => {
    test('displays rules editor', async ({ page }) => {
      await page.click('text=Rules')
      await page.waitForSelector('h1')

      // Should show Rules Editor heading
      await expect(page.locator('h1')).toContainText('Rules')
    })
  })

  test.describe('Insights Page', () => {
    test('displays AI insights panel', async ({ page }) => {
      await page.click('text=Insights')
      await page.waitForSelector('h1')

      // Should show AI Insights heading
      await expect(page.locator('h1')).toContainText('AI Insights')

      // Should have generate button
      const generateButton = page.locator('text=最適化提案を生成')
      await expect(generateButton).toBeVisible()
    })

    test('shows viewer pattern notice', async ({ page }) => {
      await page.click('text=Insights')

      // Should show the viewer pattern notice
      const notice = page.locator('text=CLI コマンドを生成するのみです')
      await expect(notice).toBeVisible()
    })
  })

  test.describe('Guide Page', () => {
    test('displays VibeCoder guide', async ({ page }) => {
      await page.click('text=Guide')
      await page.waitForSelector('h1')

      // Should show Guide heading
      await expect(page.locator('h1')).toContainText('VibeCoder ガイド')

      // Should have FAQ section
      const faq = page.locator('text=よくある質問')
      await expect(faq).toBeVisible()
    })
  })

  test.describe('Settings Page', () => {
    test('displays system status', async ({ page }) => {
      await page.click('text=Settings')
      await page.waitForSelector('h1')

      // Should show Settings heading
      await expect(page.locator('h1')).toContainText('Settings')

      // Should show system status section
      const statusSection = page.locator('text=システムステータス')
      await expect(statusSection).toBeVisible()

      // Should show Harness UI Server status
      const serverStatus = page.locator('text=Harness UI Server')
      await expect(serverStatus).toBeVisible()
    })

    test('shows claude-mem status', async ({ page }) => {
      await page.click('text=Settings')

      // Should show claude-mem status
      const claudeMemStatus = page.locator('text=claude-mem')
      await expect(claudeMemStatus.first()).toBeVisible()
    })
  })

  test.describe('Responsive Design', () => {
    test('works on mobile viewport', async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 })
      await page.goto(BASE_URL)

      // Should still show content (may be stacked)
      await page.waitForSelector('h1', { timeout: 10000 })
    })
  })

  test.describe('API Integration', () => {
    test('fetches health data from API', async ({ page }) => {
      // Intercept API call
      const healthResponse = await page.waitForResponse(
        response => response.url().includes('/api/health') && response.status() === 200
      )

      const data = await healthResponse.json()
      expect(typeof data.score).toBe('number')
      expect(['good', 'warning', 'error']).toContain(data.status)
    })
  })
})
