# init - Save Project Settings

Save workspace, scheme, simulator, and configuration for repeated use. After running init, build/run/test commands work without parameters.

```bash
# Save settings for iOS Simulator
flowdeck init -w App.xcworkspace -s MyApp -S "iPhone 16"

# Save settings for macOS
flowdeck init -w App.xcworkspace -s MyApp -D "My Mac"

# Save settings for physical device
flowdeck init -w App.xcworkspace -s MyApp -D "John's iPhone"

# Include build configuration
flowdeck init -w App.xcworkspace -s MyApp -S "iPhone 16" -C Release

# Re-initialize (overwrite existing settings)
flowdeck init -w App.xcworkspace -s MyApp -S "iPhone 16" --force

# JSON output
flowdeck init -w App.xcworkspace -s MyApp -S "iPhone 16" --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory (defaults to current) |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj |
| `-s, --scheme <name>` | Scheme name |
| `-C, --configuration <name>` | Build configuration (Debug/Release) |
| `-S, --simulator <name>` | Simulator name or UDID |
| `-D, --device <name>` | Device name or UDID (use 'My Mac' for macOS) |
| `-f, --force` | Re-initialize even if already configured |
| `--json` | Output as JSON |

**After init, use simplified commands:**
```bash
flowdeck build                # Uses saved settings
flowdeck run                  # Uses saved settings
flowdeck test             # Uses saved settings
```

---
