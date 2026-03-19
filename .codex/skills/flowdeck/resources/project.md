# project - Inspect Project Structure

Inspect schemes, build configurations, and manage Swift packages.

#### project create

Create a new Xcode project from template (SwiftUI by default).

```bash
# Create a new project in the current directory
flowdeck project create MyApp

# Set bundle ID and platforms
flowdeck project create MyApp --bundle-id com.example.myapp --platforms ios,macos,visionos

# Choose output directory and deployment targets
flowdeck project create MyApp --path ./apps --ios-target 17.0 --macos-target 14.0
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<name>` | App name (required) |

**Options:**
| Option | Description |
|--------|-------------|
| `-b, --bundle-id <id>` | Bundle identifier (default: com.example.<name>) |
| `--platforms <list>` | Comma-separated platforms: `ios`, `macos`, `visionos` (default: `ios`) |
| `-o, --path <dir>` | Output directory (default: current directory) |
| `--ios-target <version>` | iOS deployment target |
| `--macos-target <version>` | macOS deployment target |
| `--visionos-target <version>` | visionOS deployment target |
| `-j, --json` | Output as JSON |

**Notes:**
- The default template is SwiftUI.
- Multi-platform targets are only available when those SDKs are installed in Xcode.

#### project schemes

Lists all schemes available in a workspace or project.

```bash
# List schemes in a workspace
flowdeck project schemes -w App.xcworkspace

# List schemes as JSON
flowdeck project schemes -w App.xcworkspace --json

# Show usage examples
flowdeck project schemes --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory (defaults to current) |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### project configs

Lists all build configurations (e.g., Debug, Release) available in a workspace or project.

```bash
# List configurations in a workspace
flowdeck project configs -w App.xcworkspace

# List configurations as JSON
flowdeck project configs -w App.xcworkspace --json

# Show usage examples
flowdeck project configs --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory (defaults to current) |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### project packages - Manage Swift Packages

Manage Swift Package Manager dependencies.

```bash
# List installed packages
flowdeck project packages list -w App.xcworkspace

# Add a package dependency
flowdeck project packages add https://github.com/owner/repo --kind upToNextMajor --value 1.2.3

# Remove a package dependency
flowdeck project packages remove https://github.com/owner/repo

# Resolve package dependencies
flowdeck project packages resolve -w App.xcworkspace

# Update packages (clears cache and re-resolves)
flowdeck project packages update -w App.xcworkspace

# Clear package cache only
flowdeck project packages clear -w App.xcworkspace

# Link package products to a target
flowdeck project packages link https://github.com/owner/repo --target MyApp --products "RepoProduct"
```

**Subcommands:**
| Subcommand | Description |
|------------|-------------|
| `list` | List installed Swift packages |
| `add` | Add a Swift package dependency |
| `remove` | Remove a Swift package dependency |
| `resolve` | Resolve package dependencies |
| `update` | Delete cache and re-resolve packages |
| `clear` | Clear the Swift package cache (SourcePackages) |
| `link` | Link package products to a target |

**Common options (most subcommands):**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

**Subcommand-specific options:**
- `add`: `-k, --kind` (upToNextMajor, upToNextMinor, exact, branch, revision), `-V, --value`
- `resolve` / `update`: `-s, --scheme`, `--derived-data-path`
- `clear`: `--derived-data-path`
- `link`: `-t, --target`, `--products` (comma-separated)

**When to Use:**
| Problem | Solution |
|---------|----------|
| Need to inspect current packages | `flowdeck project packages list` |
| "Package not found" errors | `flowdeck project packages resolve` |
| Outdated dependencies | `flowdeck project packages update` |
| Corrupted package cache | `flowdeck project packages clear` |

For repeated package failures, use the escalation playbook in `resources/package-resolution.md`:
`update -> resolve -> clear -> clean` (last resort).

#### project sync-profiles

Sync provisioning profiles (triggers build with automatic signing).

```bash
flowdeck project sync-profiles -w App.xcworkspace -s MyApp
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj |
| `-s, --scheme <name>` | Scheme name |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed xcodebuild output |

---
