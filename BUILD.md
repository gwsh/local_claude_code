# GWSH Claude Code — Build & Packaging

## Quick Start

```bash
# Install dependencies
bun install

# Build + Package (default, produces installer for current OS)
bun run build

# Build binary only (no packaging)
bun run compile

# Dev build (no packaging)
bun run build:dev

# Dev build with all experimental features
bun run build:dev:full
```

## What You Get

Running `bun run build` produces:

| Platform | Output | Install Method |
|----------|--------|---------------|
| **Windows** | `dist/installer/gwsh-code-setup-{version}.exe` | Double-click, follow wizard |
| **macOS** | `dist/installer/gwsh-code-{version}.pkg` | Double-click, or `sudo installer -pkg ... -target /` |
| **Linux** | `dist/installer/gwsh-code-{version}-linux-x64.tar.gz` | Extract, `sudo bash install.sh` |

## Script Reference

| Command | What it does |
|---------|-------------|
| `bun run build` | Compile + package into OS installer (production) |
| `bun run compile` | Compile binary only, output to `dist/cli` |
| `bun run build:dev` | Dev build to `./cli-dev` (fast, no packaging) |
| `bun run build:dev:full` | Dev build with all 50 experimental features |
| `bun run package` | Re-package an existing `dist/cli` binary into installer |

## Advanced

### CLI flags for `scripts/build.ts`

```
--dev                  Dev build with debug version stamp
--compile              Output to dist/ instead of root
--no-package           Skip installer packaging (binary only)
--package-only         Skip build, re-package existing binary
--feature-set=dev-full Enable all 50 experimental features
--feature=FLAG         Enable a single feature flag
--outname=NAME         Custom output binary name
```

### Environment Requirements for Packaging

**Windows**: [NSIS 3.x](https://nsis.sourceforge.io/) (`winget install NSIS.NSIS`)  
**macOS**: Xcode Command Line Tools (for `pkgbuild`)  
**Linux**: `tar` (built-in)

If packaging tools are missing, the script prints a warning and leaves the raw binary.
