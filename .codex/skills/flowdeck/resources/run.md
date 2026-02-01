# run - Build and Run the App

Builds and launches an app on iOS Simulator, physical device, or macOS.

```bash
# Run on iOS Simulator
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16"

# Run on macOS
flowdeck run -w App.xcworkspace -s MyApp -D "My Mac"

# Run on Mac Catalyst (if supported by the scheme)
flowdeck run -w App.xcworkspace -s MyApp -D "My Mac Catalyst"

# Run on physical iOS device
flowdeck run -w App.xcworkspace -s MyApp -D "iPhone"

# Run with log streaming (see print() and OSLog output)
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --log

# Run without rebuilding
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --no-build

# Wait for debugger attachment
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --wait-for-debugger

# Pass app launch arguments
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --launch-options='-AppleLanguages (en)'

# Pass app launch environment variables
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --launch-env='DEBUG=1 API_ENV=staging'

# Pass xcodebuild arguments
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-quiet'

# Pass xcodebuild environment variables
flowdeck run -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-env='CI=true'
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj (REQUIRED unless init was run) |
| `-s, --scheme <name>` | Scheme name (auto-detected if only one) |
| `-S, --simulator <name>` | Simulator name or UDID (required for iOS/tvOS/watchOS) |
| `-D, --device <name>` | Device name/UDID, or "My Mac"/"My Mac Catalyst" for macOS |
| `-C, --configuration <name>` | Build configuration (Debug/Release) |
| `-d, --derived-data-path <path>` | Custom derived data path |
| `-l, --log` | Stream logs after launch (print statements + OSLog) |
| `--wait-for-debugger` | Wait for debugger to attach before app starts |
| `--no-build` | Skip build step and launch existing app |
| `--launch-options <args>` | App launch arguments (use = for values starting with -) |
| `--launch-env <vars>` | App launch environment variables |
| `--xcodebuild-options <args>` | Extra xcodebuild arguments |
| `--xcodebuild-env <vars>` | Xcodebuild environment variables |
| `-c, --config <path>` | Path to JSON config file |
| `-j, --json` | Output JSON events |
| `-v, --verbose` | Show app console output |

**Note:** Either `--simulator` or `--device` is required unless you've run `flowdeck init`. Use `--device "My Mac"` for native macOS, or `--device "My Mac Catalyst"` for Catalyst if the scheme supports it.

**After Launching:**
When the app launches, you'll get an App ID. Use it to:
- Stream logs: `flowdeck logs <app-id>`
- Stop the app: `flowdeck stop <app-id>`
- List all apps: `flowdeck apps`

---
