interface SidebarProps {
  currentPage: string
  onNavigate: (page: string) => void
}

const navItems = [
  { id: 'dashboard', label: 'Dashboard', icon: '📊' },
  { id: 'skills', label: 'Skills', icon: '⚡' },
  { id: 'commands', label: 'Commands', icon: '📋' },
  { id: 'memory', label: 'Memory', icon: '🧠' },
  { id: 'rules', label: 'Rules', icon: '📜' },
  { id: 'hooks', label: 'Hooks', icon: '🔗' },
  { id: 'usage', label: 'Usage', icon: '📈' },
  { id: 'insights', label: 'Insights', icon: '💡' },
  { id: 'guide', label: 'Guide', icon: '📖' },
]

export function Sidebar({ currentPage, onNavigate }: SidebarProps) {
  return (
    <aside className="sidebar">
      <div className="mb-6">
        <h1 className="text-xl font-bold text-primary">Harness UI</h1>
        <p className="text-sm text-muted-foreground">v1.0.0</p>
      </div>

      <nav className="space-y-1">
        {navItems.map((item) => (
          <button
            key={item.id}
            onClick={() => onNavigate(item.id)}
            className={`sidebar-link w-full text-left ${currentPage === item.id ? 'active' : ''}`}
          >
            <span>{item.icon}</span>
            <span>{item.label}</span>
          </button>
        ))}
      </nav>

      <div className="mt-auto pt-6 border-t border-border">
        <button
          onClick={() => onNavigate('settings')}
          className={`sidebar-link w-full text-left ${currentPage === 'settings' ? 'active' : ''}`}
        >
          <span>⚙️</span>
          <span>Settings</span>
        </button>
      </div>
    </aside>
  )
}
