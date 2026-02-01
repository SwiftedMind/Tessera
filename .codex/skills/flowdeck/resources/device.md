# device - Manage Physical Devices

Manage physical Apple devices connected via USB or WiFi.

#### device list

Lists all physical devices connected via USB or WiFi.

```bash
# List all connected devices
flowdeck device list

# List only iOS devices
flowdeck device list --platform iOS

# List only available devices
flowdeck device list --available-only

# Output as JSON for scripting
flowdeck device list --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-P, --platform <platform>` | Filter by platform: iOS, iPadOS, watchOS, tvOS, visionOS |
| `-A, --available-only` | Show only available devices |
| `-j, --json` | Output as JSON |

#### device install

Installs an app bundle (.app) on a physical device.

```bash
flowdeck device install <udid> /path/to/MyApp.app
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Device UDID (get from 'flowdeck device list') |
| `<app-path>` | Path to .app bundle to install |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |

#### device uninstall

Removes an installed app from a physical device.

```bash
flowdeck device uninstall <udid> com.example.myapp
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

#### device launch

Launches an installed app on a physical device.

```bash
flowdeck device launch <udid> com.example.myapp
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

---
