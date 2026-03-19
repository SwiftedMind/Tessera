# logs - Stream Real-time Logs

Stream logs for an app launched by FlowDeck. Alias: `log`. Press `Ctrl+C` to stop streaming; the app keeps running.

```bash
flowdeck logs <app-id>
flowdeck logs com.example.MyApp
flowdeck logs <app-id> --json
flowdeck logs --examples
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | App identifier (short ID, full ID, or bundle ID) |

**Options:**
| Option | Description |
|--------|-------------|
| `-j, --json` | Output JSON/NDJSON events |
| `-e, --examples` | Show usage examples |

**Filtering:**
```bash
flowdeck logs <app-id> | rg 'Pattern|thepattern'
flowdeck logs <app-id> --json | rg 'Pattern|thepattern'
```

**Notes:**
- `logs` is a live stream. If you need a bounded window, start streaming, reproduce the issue, then stop after the relevant window.
- Log streaming is supported for simulator and macOS launches. Physical device logs require Console.app or Xcode.

---
