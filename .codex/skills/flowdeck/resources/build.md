# build - Build the Project

Builds an Xcode project or workspace for the specified target platform.

```bash
# Build for iOS Simulator
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16"

# Build for macOS
flowdeck build -w App.xcworkspace -s MyApp -D "My Mac"

# Build for Mac Catalyst (if supported by the scheme)
flowdeck build -w App.xcworkspace -s MyApp -D "My Mac Catalyst"

# Build for physical iOS device (by name - partial match)
flowdeck build -w App.xcworkspace -s MyApp -D "iPhone"

# Build for physical iOS device (by UDID)
flowdeck build -w App.xcworkspace -s MyApp -D "00008130-001245110C08001C"

# Build Release configuration
flowdeck build -w App.xcworkspace -s MyApp -D "My Mac" -C Release

# Build with JSON output (for automation)
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" -j

# Custom derived data path
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" -d /tmp/DerivedData

# Pass extra xcodebuild arguments
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-quiet'
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-enableCodeCoverage YES'

# Pass xcodebuild environment variables
flowdeck build -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-env='CI=true'

# Load config from file
flowdeck build --config /path/to/config.json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj (REQUIRED unless flowdeck config set was run) |
| `-s, --scheme <name>` | Scheme name (auto-detected if only one) |
| `-S, --simulator <name>` | Simulator name or UDID (required for iOS/tvOS/watchOS) |
| `-D, --device <name>` | Device name/UDID, or "My Mac"/"My Mac Catalyst" for macOS |
| `-C, --configuration <name>` | Build configuration (Debug/Release) |
| `-d, --derived-data-path <path>` | Custom derived data path |
| `--xcodebuild-options <args>` | Extra xcodebuild arguments (use = for values starting with -) |
| `--xcodebuild-env <vars>` | Xcodebuild environment variables (e.g., 'CI=true') |
| `-c, --config <path>` | Path to JSON config file |
| `-j, --json` | Output JSON events |
| `-v, --verbose` | Show build output in console |

**Note:** Either `--simulator` or `--device` is required unless you've run `flowdeck config set`. Use `--device "My Mac"` for native macOS, or `--device "My Mac Catalyst"` for Catalyst if the scheme supports it.

---
