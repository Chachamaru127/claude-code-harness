/**
 * Projects Service - グローバルプロジェクト管理
 *
 * ~/.harness-ui/config.json でプロジェクト一覧を管理
 * claude-mem のようにプロジェクトを切り替え可能にする
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { basename, join, resolve } from 'node:path'
import { validateProjectPath } from './file-reader.ts'

// グローバル設定ディレクトリ
const CONFIG_DIR = join(homedir(), '.harness-ui')
const CONFIG_FILE = join(CONFIG_DIR, 'config.json')

/**
 * プロジェクト情報
 */
export interface Project {
  id: string
  name: string
  path: string
  addedAt: string
  lastAccessedAt?: string
}

/**
 * グローバル設定
 */
export interface GlobalConfig {
  version: string
  projects: Project[]
  activeProjectId: string | null
}

/**
 * デフォルト設定
 */
const DEFAULT_CONFIG: GlobalConfig = {
  version: '1.0.0',
  projects: [],
  activeProjectId: null,
}

/**
 * 設定ディレクトリを初期化
 */
function ensureConfigDir(): void {
  if (!existsSync(CONFIG_DIR)) {
    mkdirSync(CONFIG_DIR, { recursive: true })
  }
}

/**
 * グローバル設定を読み込む
 */
export function loadConfig(): GlobalConfig {
  ensureConfigDir()

  if (!existsSync(CONFIG_FILE)) {
    return { ...DEFAULT_CONFIG }
  }

  try {
    const content = readFileSync(CONFIG_FILE, 'utf-8')
    const config = JSON.parse(content) as GlobalConfig
    return {
      ...DEFAULT_CONFIG,
      ...config,
    }
  } catch {
    return { ...DEFAULT_CONFIG }
  }
}

/**
 * グローバル設定を保存
 */
export function saveConfig(config: GlobalConfig): void {
  ensureConfigDir()
  writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2), 'utf-8')
}

/**
 * プロジェクト一覧を取得
 */
export function getProjects(): Project[] {
  const config = loadConfig()
  return config.projects
}

/**
 * アクティブプロジェクトを取得
 */
export function getActiveProject(): Project | null {
  const config = loadConfig()
  if (!config.activeProjectId) {
    return null
  }
  return config.projects.find((p) => p.id === config.activeProjectId) ?? null
}

/**
 * アクティブプロジェクトのパスを取得
 * プロジェクトがない場合はフォールバック（環境変数 PROJECT_ROOT）
 */
export function getActiveProjectPath(): string {
  const activeProject = getActiveProject()
  if (activeProject) {
    return activeProject.path
  }
  // フォールバック: 環境変数または現在のディレクトリ
  return process.env['PROJECT_ROOT'] ?? process.cwd()
}

/**
 * プロジェクトを追加
 */
export function addProject(name: string, path: string): Project {
  // セキュリティ: パス検証
  const validatedPath = validateProjectPath(path, '/')
  if (!validatedPath) {
    throw new Error(`Invalid project path: ${path}`)
  }

  const config = loadConfig()

  // パスの重複チェック
  const existing = config.projects.find((p) => p.path === validatedPath)
  if (existing) {
    throw new Error(`Project with path "${validatedPath}" already exists`)
  }

  const project: Project = {
    id: generateId(),
    name,
    path: validatedPath,
    addedAt: new Date().toISOString(),
  }

  config.projects.push(project)

  // 最初のプロジェクトなら自動的にアクティブに
  if (config.projects.length === 1) {
    config.activeProjectId = project.id
  }

  saveConfig(config)
  return project
}

/**
 * プロジェクトを削除
 */
export function removeProject(id: string): boolean {
  const config = loadConfig()
  const index = config.projects.findIndex((p) => p.id === id)

  if (index === -1) {
    return false
  }

  config.projects.splice(index, 1)

  // アクティブプロジェクトが削除された場合
  if (config.activeProjectId === id) {
    config.activeProjectId = config.projects[0]?.id ?? null
  }

  saveConfig(config)
  return true
}

/**
 * アクティブプロジェクトを変更
 */
export function setActiveProject(id: string): Project | null {
  const config = loadConfig()
  const project = config.projects.find((p) => p.id === id)

  if (!project) {
    return null
  }

  config.activeProjectId = id
  project.lastAccessedAt = new Date().toISOString()

  saveConfig(config)
  return project
}

/**
 * プロジェクト情報を更新
 */
export function updateProject(
  id: string,
  updates: Partial<Pick<Project, 'name' | 'path'>>
): Project | null {
  const config = loadConfig()
  const project = config.projects.find((p) => p.id === id)

  if (!project) {
    return null
  }

  if (updates.name) {
    project.name = updates.name
  }
  if (updates.path) {
    // セキュリティ: パス検証
    const validatedPath = validateProjectPath(updates.path, '/')
    if (!validatedPath) {
      throw new Error(`Invalid project path: ${updates.path}`)
    }

    // パスの重複チェック
    const existing = config.projects.find(
      (p) => p.path === validatedPath && p.id !== id
    )
    if (existing) {
      throw new Error(`Project with path "${validatedPath}" already exists`)
    }
    project.path = validatedPath
  }

  saveConfig(config)
  return project
}

/**
 * プロジェクトを ID で取得
 */
export function getProjectById(id: string): Project | null {
  const config = loadConfig()
  return config.projects.find((p) => p.id === id) ?? null
}

/**
 * プロジェクトをパスで検索
 */
export function getProjectByPath(path: string): Project | null {
  // セキュリティ: パス検証
  const validatedPath = validateProjectPath(path, '/')
  if (!validatedPath) {
    return null
  }

  const config = loadConfig()
  return config.projects.find((p) => p.path === validatedPath) ?? null
}

/**
 * ランダム ID 生成
 */
function generateId(): string {
  return `proj_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`
}

/**
 * 設定ファイルのパスを取得（デバッグ用）
 */
export function getConfigPath(): string {
  return CONFIG_FILE
}

/**
 * プロジェクトルートとして不適切なディレクトリ名
 * これらのディレクトリが指定された場合は親ディレクトリを使用する
 */
const INVALID_PROJECT_DIRS = new Set([
  'harness-ui',
  '.claude',
  '.git',
  'node_modules',
  '.vscode',
  '.idea',
  'dist',
  'build',
  'out',
])

/**
 * パスからプロジェクトルートを解決
 * サブディレクトリ（.claude, node_modules など）が指定された場合は親ディレクトリを返す
 */
function resolveProjectRoot(inputPath: string): string {
  // 絶対パスに正規化
  let currentPath = resolve(inputPath)
  let dirName = basename(currentPath)

  // 無効なディレクトリの場合は親に遡る（最大3階層）
  let depth = 0
  while (INVALID_PROJECT_DIRS.has(dirName) && depth < 3) {
    currentPath = resolve(currentPath, '..')
    dirName = basename(currentPath)
    depth++
  }

  return currentPath
}

/**
 * 現在のプロジェクトを自動登録
 * claude-mem のように、セッション開始時に自動的にプロジェクトを登録する
 *
 * @param projectPath - プロジェクトパス（省略時は PROJECT_ROOT 環境変数または cwd）
 * @returns 登録されたプロジェクト（既存または新規）
 */
export function autoRegisterProject(projectPath?: string): Project | null {
  // プロジェクトパスを決定
  const rawPath = projectPath ?? process.env['PROJECT_ROOT'] ?? process.cwd()

  // サブディレクトリが指定された場合は親ディレクトリに解決
  const targetPath = resolveProjectRoot(rawPath)

  // 解決後もまだ無効なディレクトリの場合は登録しない
  const dirName = basename(targetPath)
  if (INVALID_PROJECT_DIRS.has(dirName)) {
    return null
  }

  // パス検証
  const validatedPath = validateProjectPath(targetPath, '/')
  if (!validatedPath) {
    return null
  }

  // ディレクトリが存在するか確認
  if (!existsSync(validatedPath)) {
    return null
  }

  // 既存プロジェクトを検索
  const config = loadConfig()
  const existingProject = config.projects.find((p) => p.path === validatedPath)

  if (existingProject) {
    // 既存プロジェクトをアクティブに設定
    if (config.activeProjectId !== existingProject.id) {
      config.activeProjectId = existingProject.id
      existingProject.lastAccessedAt = new Date().toISOString()
      saveConfig(config)
    }
    return existingProject
  }

  // 新規プロジェクトを作成
  const projectName = basename(validatedPath)
  const project: Project = {
    id: generateId(),
    name: projectName,
    path: validatedPath,
    addedAt: new Date().toISOString(),
    lastAccessedAt: new Date().toISOString(),
  }

  config.projects.push(project)
  config.activeProjectId = project.id
  saveConfig(config)

  return project
}

/**
 * セッション開始時の初期化
 * プロジェクトを自動登録し、アクティブに設定する
 */
export function initializeSession(): Project | null {
  return autoRegisterProject()
}
