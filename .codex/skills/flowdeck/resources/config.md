# config - Show, Save, or Reset Project Settings

Use `flowdeck config get` to read saved settings, `flowdeck config set` to save workspace/scheme/target/configuration, and `flowdeck config reset` to clear saved settings.

```bash
# Show config command help
flowdeck config

# Read saved settings for current folder
flowdeck config get
flowdeck config get --json

# Save settings for iOS Simulator
flowdeck config set -w App.xcworkspace -s MyApp -S "iPhone 16"

# Save settings for macOS
flowdeck config set -w App.xcworkspace -s MyApp -D "My Mac"

# Save settings for physical device
flowdeck config set -w App.xcworkspace -s MyApp -D "John's iPhone"

# Include build configuration
flowdeck config set -w App.xcworkspace -s MyApp -S "iPhone 16" -C Release

# Overwrite existing settings
flowdeck config set -w App.xcworkspace -s MyApp -S "iPhone 16" --force

# JSON output
flowdeck config set -w App.xcworkspace -s MyApp -S "iPhone 16" --json

# Reset saved settings
flowdeck config reset
flowdeck config reset -p /path/to/project
flowdeck config reset --json
```

**After config set, use simplified commands:**
```bash
flowdeck build
flowdeck run
flowdeck test
```

---
