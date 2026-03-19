# uninstall - Remove an Installed App

Use the top-level `uninstall` command to remove an app from a simulator or a connected device by FlowDeck app ID or bundle ID.

```bash
flowdeck uninstall <app-id>
flowdeck uninstall com.example.MyApp
flowdeck uninstall com.example.MyApp --simulator "iPhone 16"
flowdeck uninstall com.example.MyApp --device "John's iPhone"
flowdeck uninstall <app-id> --json
flowdeck uninstall com.example.MyApp --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | FlowDeck app ID (short/full) or bundle ID |

**Options:**
| Option | Description |
|--------|-------------|
| `-s, --simulator <name-or-udid>` | Target simulator name or UDID |
| `-d, --device <name-or-udid>` | Target connected device name or UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show verbose output |
| `-e, --examples` | Show usage examples |

**Notes:**
- If you omit both `--simulator` and `--device`, FlowDeck infers the target from the app ID or from the currently booted simulator.
- `uninstall` is not available for macOS apps. Use `flowdeck stop <app-id>` for macOS launches.
- For physical devices, `device uninstall <udid> <bundle-id>` is the lower-level alternative.

---
