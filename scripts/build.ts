import { chmodSync, copyFileSync, existsSync, mkdirSync, rmSync } from 'fs'
import { basename, dirname, join, resolve } from 'path'

const pkg = await Bun.file(new URL('../package.json', import.meta.url)).json() as {
  name: string
  version: string
}

const args = process.argv.slice(2)
const compile = args.includes('--compile')
const dev = args.includes('--dev')
const noPackage = args.includes('--no-package')
const packageOnly = args.includes('--package-only')

const fullExperimentalFeatures = [
  'AGENT_MEMORY_SNAPSHOT',
  'AGENT_TRIGGERS',
  'AGENT_TRIGGERS_REMOTE',
  'AWAY_SUMMARY',
  'BASH_CLASSIFIER',
  'BRIDGE_MODE',
  'BUILTIN_EXPLORE_PLAN_AGENTS',
  'CACHED_MICROCOMPACT',
  'CCR_AUTO_CONNECT',
  'CCR_MIRROR',
  'CCR_REMOTE_SETUP',
  'COMPACTION_REMINDERS',
  'CONNECTOR_TEXT',
  'EXTRACT_MEMORIES',
  'HISTORY_PICKER',
  'HOOK_PROMPTS',
  'KAIROS_BRIEF',
  'KAIROS_CHANNELS',
  'LODESTONE',
  'MCP_RICH_OUTPUT',
  'MESSAGE_ACTIONS',
  'NATIVE_CLIPBOARD_IMAGE',
  'NEW_INIT',
  'POWERSHELL_AUTO_MODE',
  'PROMPT_CACHE_BREAK_DETECTION',
  'QUICK_SEARCH',
  'SHOT_STATS',
  'TEAMMEM',
  'TOKEN_BUDGET',
  'TREE_SITTER_BASH',
  'TREE_SITTER_BASH_SHADOW',
  'ULTRAPLAN',
  'ULTRATHINK',
  'UNATTENDED_RETRY',
  'VERIFICATION_AGENT',
  'VOICE_MODE',
] as const

function runCommand(cmd: string[]): string | null {
  const proc = Bun.spawnSync({
    cmd,
    cwd: process.cwd(),
    stdout: 'pipe',
    stderr: 'pipe',
  })

  if (proc.exitCode !== 0) {
    return null
  }

  return new TextDecoder().decode(proc.stdout).trim() || null
}

function runCommandInherit(cmd: string[]): number {
  const proc = Bun.spawnSync({
    cmd,
    cwd: process.cwd(),
    stdout: 'inherit',
    stderr: 'inherit',
  })
  return proc.exitCode ?? 1
}

function getDevVersion(baseVersion: string): string {
  const timestamp = new Date().toISOString()
  const date = timestamp.slice(0, 10).replaceAll('-', '')
  const time = timestamp.slice(11, 19).replaceAll(':', '')
  const sha = runCommand(['git', 'rev-parse', '--short=8', 'HEAD']) ?? 'unknown'
  return `${baseVersion}-dev.${date}.t${time}.sha${sha}`
}

function getVersionChangelog(): string {
  return (
    runCommand(['git', 'log', '--format=%h %s', '-20']) ??
    'Local development build'
  )
}

// ─── OS detection ───

const platform = process.platform as 'darwin' | 'linux' | 'win32'
const isWindows = platform === 'win32'
const isMacOS = platform === 'darwin'
const isLinux = platform === 'linux'

// ─── Feature flags ───

const defaultFeatures = ['VOICE_MODE']
const featureSet = new Set(defaultFeatures)
for (let i = 0; i < args.length; i += 1) {
  const arg = args[i]
  if (arg === '--feature-set' && args[i + 1]) {
    if (args[i + 1] === 'dev-full') {
      for (const feature of fullExperimentalFeatures) {
        featureSet.add(feature)
      }
    }
    i += 1
    continue
  }
  if (arg === '--feature-set=dev-full') {
    for (const feature of fullExperimentalFeatures) {
      featureSet.add(feature)
    }
    continue
  }
  if (arg === '--feature' && args[i + 1]) {
    featureSet.add(args[i + 1]!)
    i += 1
    continue
  }
  if (arg.startsWith('--feature=')) {
    featureSet.add(arg.slice('--feature='.length))
  }
}
const features = [...featureSet]

// ─── Output path ───

let outname = 'gclaude'
for (let i = 0; i < args.length; i++) {
  if (args[i]!.startsWith('--outname=')) {
    outname = args[i]!.slice('--outname='.length)
    break
  }
}

const outfile = compile
  ? dev
    ? `./dist/${outname}-dev`
    : `./dist/${outname}`
  : dev
    ? `./${outname}-dev`
    : `./${outname}`

// Actual binary path (Bun appends .exe on Windows with --compile)
const binaryPath = isWindows ? `${outfile}.exe` : outfile

const buildTime = new Date().toISOString()
const version = dev ? getDevVersion(pkg.version) : pkg.version

// ─── Build step ───

async function build(): Promise<void> {
  // Skip build if --package-only
  if (packageOnly) {
    if (!existsSync(binaryPath)) {
      console.error(`Error: --package-only specified but binary not found at ${binaryPath}`)
      console.error('Build the binary first, then run with --package-only')
      process.exit(1)
    }
    console.log(`Skipping build, using existing binary: ${binaryPath}`)
    return
  }

  const outDir = dirname(outfile)
  if (outDir !== '.') {
    mkdirSync(outDir, { recursive: true })
  }

  const externals = [
    '@ant/*',
    'audio-capture-napi',
    'image-processor-napi',
    'modifiers-napi',
    'url-handler-napi',
  ]

  const defines = {
    'process.env.USER_TYPE': JSON.stringify('external'),
    'process.env.CLAUDE_CODE_FORCE_FULL_LOGO': JSON.stringify('true'),
    ...(dev
      ? { 'process.env.NODE_ENV': JSON.stringify('development') }
      : {}),
    ...(dev
      ? {
          'process.env.CLAUDE_CODE_EXPERIMENTAL_BUILD': JSON.stringify('true'),
        }
      : {}),
    'process.env.CLAUDE_CODE_VERIFY_PLAN': JSON.stringify('false'),
    'process.env.CCR_FORCE_BUNDLE': JSON.stringify('true'),
    'MACRO.VERSION': JSON.stringify(version),
    'MACRO.BUILD_TIME': JSON.stringify(buildTime),
    'MACRO.PACKAGE_URL': JSON.stringify(pkg.name),
    'MACRO.NATIVE_PACKAGE_URL': 'undefined',
    'MACRO.FEEDBACK_CHANNEL': JSON.stringify('github'),
    'MACRO.ISSUES_EXPLAINER': JSON.stringify(
      'This reconstructed source snapshot does not include Anthropic internal issue routing.',
    ),
    'MACRO.VERSION_CHANGELOG': JSON.stringify(
      dev ? getVersionChangelog() : 'https://github.com/paoloanzn/claude-code',
    ),
  } as const

  const cmd = [
    'bun',
    'build',
    './src/entrypoints/cli.tsx',
    '--compile',
    '--target',
    'bun',
    '--format',
    'esm',
    '--outfile',
    outfile,
    '--minify',
    '--bytecode',
    '--packages',
    'bundle',
    '--conditions',
    'bun',
  ]

  for (const external of externals) {
    cmd.push('--external', external)
  }

  for (const feature of features) {
    cmd.push(`--feature=${feature}`)
  }

  for (const [key, value] of Object.entries(defines)) {
    cmd.push('--define', `${key}=${value}`)
  }

  console.log(`Building ${outfile} (${features.length} features)...`)
  const exitCode = runCommandInherit(cmd)
  if (exitCode !== 0) {
    process.exit(exitCode)
  }

  if (!existsSync(binaryPath)) {
    console.error(`Error: Build completed but binary not found at ${binaryPath}`)
    process.exit(1)
  }

  chmodSync(binaryPath, 0o755)
  console.log(`Built ${binaryPath}`)
}

// ─── Package step ───

async function packageWindows(): Promise<void> {
  console.log('')
  console.log('=== Packaging for Windows ===')

  const installerDir = 'dist/installer'
  mkdirSync(installerDir, { recursive: true })

  // Step 1: Generate ICO icon from PNG (uses node for sharp+to-ico compat)
  console.log('Generating icon...')
  const iconPath = 'png/logo.ico'
  const icoExit = runCommandInherit([
    'node', '-e',
    `const sharp=require('sharp'),fs=require('fs'),toIco=require('to-ico');` +
    `sharp('png/logo.png').resize(256,256).ensureAlpha().png().toBuffer()` +
    `.then(b=>toIco(b)).then(b=>fs.writeFileSync('png/logo.ico',b))`
  ])
  if (icoExit !== 0 || !existsSync(iconPath)) {
    console.warn('Warning: Icon generation failed, continuing without icon')
  } else {
    console.log(`Icon created: ${iconPath}`)
  }

  // Step 2: Inject icon with rcedit (binary is already dist/gclaude.exe)
  console.log('Injecting icon...')
  const rceditPath = './node_modules/rcedit/bin/rcedit.exe'
  if (existsSync(rceditPath)) {
    const rcExit = runCommandInherit([rceditPath, binaryPath, '--set-icon', iconPath])
    if (rcExit !== 0) {
      console.warn('Warning: rcedit failed, continuing without icon injection')
    } else {
      console.log('Icon injected successfully')
    }
  } else {
    console.warn('rcedit not found, skipping icon injection')
  }

  // Step 4: Build NSIS installer
  const nsisPaths = [
    'C:\\Program Files (x86)\\NSIS\\makensis.exe',
    'C:\\Program Files\\NSIS\\makensis.exe',
  ]
  let makensis = ''
  for (const p of nsisPaths) {
    if (existsSync(p)) {
      makensis = p
      break
    }
  }
  // Also check PATH
  if (!makensis) {
    const which = runCommand(['where', 'makensis'])
    if (which) makensis = which.split('\n')[0]!.trim()
  }

  if (!makensis) {
    console.warn('')
    console.warn('==============================================')
    console.warn('  NSIS (makensis) not found!')
    console.warn('  Install NSIS to build the Windows installer:')
    console.warn('    winget install NSIS.NSIS')
    console.warn('')
    console.warn('  Raw binary available at: dist/gclaude.exe')
    console.warn('==============================================')
    return
  }

  const setupName = `gwsh-code-setup-${version}.exe`
  const setupPath = resolve(installerDir, setupName)
  console.log(`Building NSIS installer: ${setupPath}...`)
  const nsisExit = runCommandInherit([
    makensis,
    `/DPRODUCT_VERSION=${version}`,
    `/DOUTFILE=${setupPath}`,
    'scripts/installer/windows.nsi',
  ])
  if (nsisExit !== 0) {
    console.error('NSIS build failed')
    process.exit(1)
  }

  console.log('')
  console.log('==============================================')
  console.log(`  Windows installer: ${setupPath}`)
  console.log('==============================================')
}

async function packageMacOS(): Promise<void> {
  console.log('')
  console.log('=== Packaging for macOS ===')

  const installerDir = 'dist/installer'
  mkdirSync(installerDir, { recursive: true })

  // Create a temporary package root structure
  const pkgRoot = 'dist/.pkg-root'
  const binDir = join(pkgRoot, 'usr/local/bin')
  mkdirSync(binDir, { recursive: true })

  // Copy binary
  const destBinary = join(binDir, 'gclaude')
  copyFileSync(binaryPath, destBinary)
  chmodSync(destBinary, 0o755)

  // Create postinstall script (sets up PATH hint in shell profiles)
  const scriptsDir = 'dist/.pkg-scripts'
  mkdirSync(scriptsDir, { recursive: true })
  const postinstallPath = join(scriptsDir, 'postinstall')
  Bun.write(postinstallPath, `#!/bin/bash
# GWSH Claude Code postinstall
BIN_PATH="/usr/local/bin/gclaude"
PROFILE_FILES=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zprofile")

for pf in "\${PROFILE_FILES[@]}"; do
  if [ -f "$pf" ] && ! grep -q "gclaude" "$pf" 2>/dev/null; then
    echo "" >> "$pf"
    echo "# GWSH Claude Code" >> "$pf"
    echo 'export PATH="/usr/local/bin:$PATH"' >> "$pf"
  fi
done
echo "GWSH Claude Code installed successfully!"
echo "Run 'gclaude' to start. If the command is not found, restart your terminal."
exit 0
`)
  chmodSync(postinstallPath, 0o755)

  // Build .pkg with pkgbuild
  const pkgName = `gwsh-code-${version}.pkg`
  const pkgPath = join(installerDir, pkgName)

  // Check if pkgbuild is available
  const pkgbuildCheck = runCommand(['which', 'pkgbuild'])
  if (!pkgbuildCheck) {
    console.warn('')
    console.warn('==============================================')
    console.warn('  pkgbuild not found!')
    console.warn('  This should be available on macOS by default.')
    console.warn('  Make sure you are running on macOS with Xcode Command Line Tools.')
    console.warn('')
    console.warn('  Raw binary available at: dist/gclaude')
    console.warn('==============================================')
    // Cleanup
    rmSync(pkgRoot, { recursive: true, force: true })
    rmSync(scriptsDir, { recursive: true, force: true })
    return
  }

  console.log(`Building .pkg installer: ${pkgPath}...`)
  const pkgExit = runCommandInherit([
    'pkgbuild',
    '--root', pkgRoot,
    '--scripts', scriptsDir,
    '--identifier', 'com.gwsh.claude-code',
    '--version', version,
    '--install-location', '/',
    pkgPath,
  ])
  if (pkgExit !== 0) {
    console.error('pkgbuild failed')
    process.exit(1)
  }

  // Cleanup temp dirs
  rmSync(pkgRoot, { recursive: true, force: true })
  rmSync(scriptsDir, { recursive: true, force: true })

  console.log('')
  console.log('==============================================')
  console.log(`  macOS installer: ${pkgPath}`)
  console.log('  Double-click to install, or:')
  console.log(`    sudo installer -pkg ${pkgPath} -target /`)
  console.log('==============================================')
}

async function packageLinux(): Promise<void> {
  console.log('')
  console.log('=== Packaging for Linux ===')

  const installerDir = 'dist/installer'
  mkdirSync(installerDir, { recursive: true })

  // Create install script
  const installScript = `#!/usr/bin/env bash
set -euo pipefail
INSTALL_DIR="/usr/local/lib/gwsh-code"
BIN_LINK="/usr/local/bin/gclaude"

if [ "\$(id -u)" -ne 0 ]; then
  echo "This installer requires sudo. Re-run with: sudo bash $0"
  exit 1
fi

echo "Installing GWSH Claude Code ${version}..."
mkdir -p "\$INSTALL_DIR"
cp "\$(dirname "\$0")/gclaude" "\$INSTALL_DIR/gclaude"
chmod 755 "\$INSTALL_DIR/gclaude"
ln -sf "\$INSTALL_DIR/gclaude" "\$BIN_LINK"
echo "Done! Run 'gclaude' to start."
echo "First time? Use 'gclaude /login' for OAuth, or set ANTHROPIC_API_KEY."
`

  // Create temp packaging dir
  const pkgDir = `dist/.pkg-gwsh-code-${version}`
  mkdirSync(pkgDir, { recursive: true })

  // Copy binary
  const destBinary = join(pkgDir, 'gclaude')
  copyFileSync(binaryPath, destBinary)
  chmodSync(destBinary, 0o755)

  // Write install script
  Bun.write(join(pkgDir, 'install.sh'), installScript)
  chmodSync(join(pkgDir, 'install.sh'), 0o755)

  // Create tar.gz
  const archiveName = `gwsh-code-${version}-linux-x64.tar.gz`
  const archivePath = join(installerDir, archiveName)
  console.log(`Creating archive: ${archivePath}...`)

  const tarExit = runCommandInherit([
    'tar', '-czf', archivePath,
    '-C', 'dist',
    basename(pkgDir),
  ])
  if (tarExit !== 0) {
    console.error('tar failed')
    process.exit(1)
  }

  // Cleanup
  rmSync(pkgDir, { recursive: true, force: true })

  console.log('')
  console.log('==============================================')
  console.log(`  Linux archive: ${archivePath}`)
  console.log(`  Install: tar -xzf ${archiveName} && cd gwsh-code-* && sudo bash install.sh`)
  console.log('==============================================')
}

async function packageAll(): Promise<void> {
  switch (platform) {
    case 'win32':
      await packageWindows()
      break
    case 'darwin':
      await packageMacOS()
      break
    case 'linux':
      await packageLinux()
      break
    default:
      console.warn(`Unknown platform: ${platform}, skipping packaging`)
  }
}

// ─── Main ───

async function main(): Promise<void> {
  await build()

  if (!noPackage) {
    await packageAll()
  }
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
