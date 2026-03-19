# stop - Stop Running App

Terminate an app launched by FlowDeck.

```bash
flowdeck stop <app-id>
flowdeck stop com.example.MyApp
flowdeck stop --all
flowdeck stop <app-id> --force
flowdeck stop --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | App identifier (short ID, full ID, or bundle ID) |

**Options:**
| Option | Description |
|--------|-------------|
| `-a, --all` | Stop all running apps |
| `-f, --force` | Force kill (`SIGKILL`) instead of graceful termination |
| `-j, --json` | Output JSON/NDJSON events |
| `-e, --examples` | Show usage examples |

---
