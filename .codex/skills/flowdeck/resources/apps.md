# apps - List Running Apps

Shows all apps currently running that were launched by FlowDeck.

```bash
# List running apps
flowdeck apps

# Include stopped apps
flowdeck apps --all

# Clean up stale entries
flowdeck apps --prune

# JSON output
flowdeck apps --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-a, --all` | Show all apps including stopped ones |
| `--prune` | Validate and prune stale entries |
| `-j, --json` | Output as JSON |

**Returns:** App IDs, bundle IDs, PIDs, and simulators.

**Next Steps:** After getting an App ID, you can:
- `flowdeck logs <app-id>` - Stream logs from the app
- `flowdeck stop <app-id>` - Stop the app

---
