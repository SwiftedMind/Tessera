# stop - Stop Running App

Terminates an app that was launched by FlowDeck.

```bash
# Stop specific app (use ID from 'flowdeck apps')
flowdeck stop abc123

# Stop by bundle ID
flowdeck stop com.example.myapp

# Stop all running apps
flowdeck stop --all

# Force kill unresponsive app
flowdeck stop abc123 --force

# Force kill all running apps
flowdeck stop --all --force

# JSON output
flowdeck stop abc123 --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | App identifier (short ID, full ID, or bundle ID) |

**Options:**
| Option | Description |
|--------|-------------|
| `-a, --all` | Stop all running apps |
| `-f, --force` | Force kill (SIGKILL instead of SIGTERM) |
| `-j, --json` | Output as JSON |

---
