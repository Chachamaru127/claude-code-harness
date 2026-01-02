import { useState } from 'react'
import { Sidebar } from './components/Sidebar.tsx'
import { Dashboard } from './components/Dashboard.tsx'
import { SkillsManager } from './components/SkillsManager.tsx'
import { MemoryAnalyzer } from './components/MemoryAnalyzer.tsx'
import { RulesEditor } from './components/RulesEditor.tsx'
import { UsageManager } from './components/UsageManager.tsx'
import { InsightsPanel } from './components/InsightsPanel.tsx'
import { Guide } from './components/Guide.tsx'
import { Settings } from './components/Settings.tsx'

type Page = 'dashboard' | 'skills' | 'memory' | 'rules' | 'usage' | 'insights' | 'guide' | 'settings'

export function App() {
  const [currentPage, setCurrentPage] = useState<Page>('dashboard')

  const renderPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <Dashboard onNavigate={(page) => setCurrentPage(page as Page)} />
      case 'skills':
        return <SkillsManager />
      case 'memory':
        return <MemoryAnalyzer />
      case 'rules':
        return <RulesEditor />
      case 'usage':
        return <UsageManager />
      case 'insights':
        return <InsightsPanel />
      case 'guide':
        return <Guide />
      case 'settings':
        return <Settings />
      default:
        return <Dashboard />
    }
  }

  return (
    <div className="flex">
      <Sidebar currentPage={currentPage} onNavigate={(page) => setCurrentPage(page as Page)} />
      <main className="main-content flex-1">
        {renderPage()}
      </main>
    </div>
  )
}
