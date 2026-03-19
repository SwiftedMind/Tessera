# simulator - Manage Simulators

Manage iOS, iPadOS, watchOS, tvOS, and visionOS simulators.

#### simulator list

Lists all simulators installed on your system.

```bash
# List all simulators
flowdeck simulator list

# List only iOS simulators
flowdeck simulator list --platform iOS

# List only available simulators
flowdeck simulator list --available-only

# Output as JSON for scripting
flowdeck simulator list --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-P, --platform <platform>` | Filter by platform (iOS, tvOS, watchOS, visionOS) |
| `-A, --available-only` | Show only available simulators |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator boot

Boots a simulator so it's ready to run apps.

```bash
# Boot by UDID
flowdeck simulator boot <udid>
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Simulator UDID (get from 'flowdeck simulator list') |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator shutdown

Shuts down a running simulator.

```bash
# Shutdown by UDID
flowdeck simulator shutdown <udid>
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<udid>` | Simulator UDID |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator open

Opens the Simulator.app application.

```bash
flowdeck simulator open
```

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator create

Creates a new simulator with the specified device type and runtime.

```bash
flowdeck simulator create -n "My iPhone 16" --device-type "iPhone 16 Pro" --runtime "iOS 18.1"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-n, --name <name>` | Name for the new simulator (required) |
| `--device-type <type>` | Device type (required) |
| `--runtime <runtime>` | Runtime (required) |
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator delete

Deletes a simulator by UDID or name.

```bash
flowdeck simulator delete <UDID>
flowdeck simulator delete "iPhone 16"
flowdeck simulator delete _ --unavailable
```

**Options:**
| Option | Description |
|--------|-------------|
| `--unavailable` | Delete all unavailable simulators |
| `-v, --verbose` | Show command output |
| `-e, --examples` | Show usage examples |

#### simulator prune

Deletes unused simulators (never booted).

```bash
flowdeck simulator prune --dry-run
flowdeck simulator prune
```

**Options:**
| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be deleted without deleting |
| `-v, --verbose` | Show verbose output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator erase

Erases all content and settings from a simulator.

```bash
flowdeck simulator erase <UDID>
flowdeck simulator erase <UDID> --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Note:** The simulator must be shutdown before erasing.

#### simulator clear-cache

Clears simulator caches.

```bash
flowdeck simulator clear-cache
flowdeck simulator clear-cache --verbose
```

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-e, --examples` | Show usage examples |

#### simulator device-types

Lists available simulator device types.

```bash
flowdeck simulator device-types
flowdeck simulator device-types --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

## simulator runtime - Manage Simulator Runtimes

Manage simulator runtimes (iOS, tvOS, watchOS, visionOS versions).

#### simulator runtime list

Lists all simulator runtimes installed on your system.

```bash
flowdeck simulator runtime list
flowdeck simulator runtime list --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator runtime available

List downloadable runtimes from Apple.

```bash
flowdeck simulator runtime available
flowdeck simulator runtime available --platform iOS
flowdeck simulator runtime available --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-P, --platform <platform>` | Filter by platform (iOS, tvOS, watchOS, visionOS) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator runtime create

Download and install a simulator runtime.

```bash
# Install latest iOS runtime
flowdeck simulator runtime create iOS

# Install specific version
flowdeck simulator runtime create iOS 18.0

# Install and prune auto-created simulators
flowdeck simulator runtime create iOS 18.0 --prune
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<platform>` | Platform: iOS, tvOS, watchOS, or visionOS |
| `<version>` | Version (e.g., 18.0). Omit for latest. |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `--prune` | Remove auto-created simulators after install |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator runtime delete

Remove a simulator runtime.

```bash
flowdeck simulator runtime delete "iOS 17.2"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<runtime>` | Runtime name (e.g., "iOS 17.2") or runtime identifier |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator runtime prune

Delete all simulators for a specific runtime.

```bash
flowdeck simulator runtime prune "iOS 18.0"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<runtime>` | Runtime name (e.g., "iOS 18.0") or runtime identifier |

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show deleted simulator UDIDs |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### simulator location set

Set simulator location coordinates.

```bash
flowdeck simulator location set 37.7749,-122.4194
flowdeck simulator location set 37.7749,-122.4194 --udid <UDID>
flowdeck simulator location set 37.7749,-122.4194 --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<lat,lon>` | Coordinates in `latitude,longitude` format |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID (defaults to first booted simulator) |
| `-j, --json` | Output as JSON |

#### simulator media add

Add media to a simulator (photos or videos).

```bash
flowdeck simulator media add /path/to/photo.jpg
flowdeck simulator media add /path/to/video.mov --udid <UDID>
flowdeck simulator media add /path/to/photo.jpg --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<file>` | Path to media file |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID (defaults to first booted simulator) |
| `-j, --json` | Output as JSON |

---
