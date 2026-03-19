# device - Manage Physical Devices

Manage physical Apple devices connected via USB or WiFi.

#### device list

List connected physical devices and virtual macOS targets.

```bash
flowdeck device list
flowdeck device list --platform iOS
flowdeck device list --available-only
flowdeck device list --json
flowdeck device list --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `-P, --platform <platform>` | Filter by platform: `iOS`, `iPadOS`, `watchOS`, `tvOS`, `visionOS` |
| `-A, --available-only` | Show only available devices |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Note:** JSON output can include virtual targets like `My Mac` and `My Mac Catalyst`.

#### device install

Install an app bundle (`.app`) on a physical device.

```bash
flowdeck device install <udid> /path/to/MyApp.app
flowdeck device install <udid> /path/to/MyApp.app --json
flowdeck device install <udid> /path/to/MyApp.app --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Device UDID |
| `<app-path>` | Path to the `.app` bundle |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### device uninstall

Remove an installed app from a physical device.

```bash
flowdeck device uninstall <udid> com.example.MyApp
flowdeck device uninstall <udid> com.example.MyApp --json
flowdeck device uninstall <udid> com.example.MyApp --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Device UDID |
| `<bundle-id>` | App bundle identifier |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### device launch

Launch an installed app on a physical device.

```bash
flowdeck device launch <udid> com.example.MyApp
flowdeck device launch <udid> com.example.MyApp --json
flowdeck device launch <udid> com.example.MyApp --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Device UDID |
| `<bundle-id>` | App bundle identifier |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Tip:** Use `flowdeck device list --json` to get device UDIDs.

---
