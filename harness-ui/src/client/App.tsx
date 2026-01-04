import { useState, createContext, useContext } from 'react'
import { Sidebar } from './components/Sidebar.tsx'
import { Dashboard } from './components/Dashboard.tsx'
import { SkillsManager } from './components/SkillsManager.tsx'
import { CommandsManager } from './components/CommandsManager.tsx'
import { MemoryAnalyzer } from './components/MemoryAnalyzer.tsx'
import { RulesEditor } from './components/RulesEditor.tsx'
import { HooksManager } from './components/HooksManager.tsx'
import { UsageManager } from './components/UsageManager.tsx'
import { InsightsPanel } from './components/InsightsPanel.tsx'
import { Guide } from './components/Guide.tsx'
import { Settings } from './components/Settings.tsx'
import { ProjectSelector } from './components/ProjectSelector.tsx'
import type { Project } from './lib/api.ts'

type Page = 'dashboard' | 'skills' | 'commands' | 'memory' | 'rules' | 'hooks' | 'usage' | 'insights' | 'guide' | 'settings'

// プロジェクトコンテキスト
interface ProjectContextType {
  activeProject: Project | null
  setActiveProject: (project: Project | null) => void
}

export const ProjectContext = createContext<ProjectContextType>({
  activeProject: null,
  setActiveProject: () => {},
})

export function useProject() {
  return useContext(ProjectContext)
}

export function App() {
  const [currentPage, setCurrentPage] = useState<Page>('dashboard')
  const [activeProject, setActiveProject] = useState<Project | null>(null)

  const renderPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <Dashboard onNavigate={(page) => setCurrentPage(page as Page)} />
      case 'skills':
        return <SkillsManager />
      case 'commands':
        return <CommandsManager />
      case 'memory':
        return <MemoryAnalyzer />
      case 'rules':
        return <RulesEditor />
      case 'hooks':
        return <HooksManager />
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
    <ProjectContext.Provider value={{ activeProject, setActiveProject }}>
      <div className="app-layout">
        {/* ヘッダー */}
        <header className="app-header">
          <div className="header-logo">
            <span className="logo-icon">🔧</span>
            <span className="logo-text">harness-ui</span>
          </div>
          <div className="header-actions">
            <ProjectSelector onProjectChange={setActiveProject} />
          </div>
        </header>

        {/* メインコンテンツ */}
        <div className="app-body">
          <Sidebar currentPage={currentPage} onNavigate={(page) => setCurrentPage(page as Page)} />
          <main className="main-content flex-1">
            {/* プロジェクト情報バー */}
            {activeProject && (
              <div className="project-info-bar">
                <span className="project-info-icon">📁</span>
                <span className="project-info-path">{activeProject.path}</span>
              </div>
            )}
            {renderPage()}
          </main>
        </div>
      </div>
    </ProjectContext.Provider>
  )
}
