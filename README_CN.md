# Local Claude Code

基于 [free-code](https://github.com/paoloanzn/free-code) 和 [Claude Code](https://github.com/anthropics/claude-code) 构建的桌面安装版。提供 Windows、macOS、Linux 的一键安装程序 — 无需配置终端、无需手动安装依赖。

> [English](README.md) | 中文

## 项目起源

本项目 Fork 自 [free-code](https://github.com/paoloanzn/free-code)，而 free-code 是 Anthropic 官方 [Claude Code](https://github.com/anthropics/claude-code) CLI 的社区构建版本。

核心目标：**让安装变得极其简单**。下载安装包 → 双击安装 → 开始编码。不需要配置 Node/Bun，不需要命令行操作。

## 快速开始

### Windows

1. 从 [Releases](../../releases) 页面下载最新的 `gwsh-code-setup-x.x.x.exe`
2. 双击运行安装程序（自动检测 Git、配置 PATH、创建开始菜单快捷方式）
3. 打开终端，输入 `gclaude`
4. 首次使用运行 `gclaude /login` 进行 OAuth 认证，或设置 `ANTHROPIC_API_KEY` 环境变量

### macOS

1. 从 [Releases](../../releases) 页面下载最新的 `gwsh-code-x.x.x.pkg`
2. 双击安装，或使用命令行：`sudo installer -pkg gwsh-code-x.x.x.pkg -target /`
3. 打开终端，输入 `gclaude`
4. 首次使用运行 `gclaude /login` 进行 OAuth 认证

### Linux

1. 从 [Releases](../../releases) 页面下载最新的 `gwsh-code-x.x.x-linux-x64.tar.gz`
2. 解压并运行安装脚本：
   ```bash
   tar -xzf gwsh-code-*-linux-x64.tar.gz
   cd gwsh-code-*
   sudo bash install.sh
   ```
3. 输入 `gclaude` 启动

## 模型提供商

内置支持以下五种模型提供商：

| 提供商 | 启用方式 | 认证方式 |
|--------|----------|----------|
| Anthropic（默认） | -- | `ANTHROPIC_API_KEY` 或 OAuth |
| OpenAI Codex | `CLAUDE_CODE_USE_OPENAI=1` | OAuth |
| AWS Bedrock | `CLAUDE_CODE_USE_BEDROCK=1` | AWS 凭据 |
| Google Vertex AI | `CLAUDE_CODE_USE_VERTEX=1` | `gcloud` ADC |
| Anthropic Foundry | `CLAUDE_CODE_USE_FOUNDRY=1` | `ANTHROPIC_FOUNDRY_API_KEY` |

## 从源码构建

```bash
# 安装依赖
bun install

# 标准构建 + 打包（自动检测平台）
bun run build

# 仅编译二进制（不打包）
bun run compile

# 仅打包（跳过编译，使用已有二进制）
bun run package
```

### 构建变体

| 命令 | 输出 | 说明 |
|------|------|------|
| `bun run build` | `./dist/gclaude` + 安装包 | 标准构建 + 平台打包 |
| `bun run build:dev` | `./gclaude-dev` | 开发版本 |
| `bun run build:dev:full` | `./gclaude-dev` | 启用全部实验性功能 |
| `bun run compile` | `./dist/gclaude` | 仅编译，不打包 |

### 按平台打包

在对应平台上运行：

```bash
# Windows（需要 NSIS）
bun run build    # → dist/installer/gwsh-code-setup-x.x.x.exe

# macOS（需要 Xcode CLI Tools）
bun run build    # → dist/installer/gwsh-code-x.x.x.pkg

# Linux
bun run build    # → dist/installer/gwsh-code-x.x.x-linux-x64.tar.gz
```

### 环境要求

- [Bun](https://bun.sh) >= 1.3.11
- **Windows**：[NSIS](https://nsis.sourceforge.io/)（`winget install NSIS.NSIS`）用于生成安装程序
- **macOS**：Xcode Command Line Tools（`pkgbuild` 已内置）
- **Linux**：无需额外依赖（生成 tar.gz 压缩包）

## 使用方式

```bash
# 交互式 REPL（默认）
./gclaude

# 单次问答模式
./gclaude -p "解释这个目录下的代码"

# 指定模型
./gclaude --model claude-opus-4-6

# OAuth 登录
./gclaude /login
```

## 项目结构

```
scripts/
  build.ts                # 构建脚本与功能开关系统

src/
  entrypoints/cli.tsx     # CLI 入口
  commands.ts             # 斜杠命令注册
  tools.ts                # Agent 工具注册
  QueryEngine.ts          # LLM 查询引擎
  screens/REPL.tsx        # 主交互界面 (Ink/React)

  commands/               # 斜杠命令实现
  tools/                  # Agent 工具实现 (Bash, Read, Edit 等)
  components/             # Ink/React 终端 UI 组件
  hooks/                  # React Hooks
  services/               # API 客户端、MCP、OAuth、分析
    api/                  # API 客户端 + Codex 适配器
    oauth/                # OAuth 流程 (Anthropic + OpenAI)
  state/                  # 应用状态管理
  utils/                  # 工具函数
    model/                # 模型配置、提供商、验证
  skills/                 # 技能系统
  plugins/                # 插件系统
  bridge/                 # IDE Bridge
  voice/                  # 语音输入
  tasks/                  # 后台任务管理
```

## 技术栈

| 分类 | 技术 |
|------|------|
| **运行时** | [Bun](https://bun.sh) |
| **语言** | TypeScript |
| **终端 UI** | React + [Ink](https://github.com/vadimdemedes/ink) |
| **CLI 解析** | [Commander.js](https://github.com/tj/commander.js) |
| **Schema 校验** | Zod v4 |
| **代码搜索** | ripgrep（内置） |
| **协议** | MCP、LSP |
| **API** | Anthropic Messages、OpenAI Codex、AWS Bedrock、Google Vertex AI |

## 上游项目

- [Claude Code](https://github.com/anthropics/claude-code) — Anthropic 官方 CLI AI 编程助手
- [free-code](https://github.com/paoloanzn/free-code) — Claude Code 的社区构建版本

## License

本项目基于 [free-code](https://github.com/paoloanzn/free-code) 构建，原始 Claude Code 源代码版权归 Anthropic 所有。请酌情使用。
