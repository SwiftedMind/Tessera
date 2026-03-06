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

---
