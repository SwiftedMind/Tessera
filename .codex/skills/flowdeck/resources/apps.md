# apps - List Running Apps

List apps launched by FlowDeck, including status and identifiers.

```bash
flowdeck apps
flowdeck apps --all
flowdeck apps --prune
flowdeck apps --json
flowdeck apps --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `-a, --all` | Show all apps including stopped ones |
| `--prune` | Validate and prune stale entries |
| `-j, --json` | Output JSON/NDJSON events |
| `-e, --examples` | Show usage examples |

**JSON Output:**
- `apps --json` emits an NDJSON event with type `app_list`.
- The app list is available under `data.apps`.

**Next Steps:**
- `flowdeck logs <app-id>` to stream logs
- `flowdeck stop <app-id>` to stop the app
- `flowdeck uninstall <app-id>` to uninstall from a simulator or device

---
