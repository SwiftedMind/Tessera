# logs - Stream Real-time Logs

Streams print() statements and OSLog messages from a running app. Alias: `log`. Press Ctrl+C to stop streaming (the app keeps running).

```bash
# Stream logs (use App ID from 'flowdeck apps')
flowdeck logs abc123

# Stream logs by bundle ID
flowdeck logs com.example.myapp

# Stream logs in JSON format
flowdeck logs abc123 --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | App identifier (short ID, full ID, or bundle ID) |

**Options:**
| Option | Description |
|--------|-------------|
| `--json` | Output as JSON |

**Output Format:**
- `[console]` - Messages from print() statements
- `[category]` - Messages from os_log() with category
- `[subsystem]` - Messages from Logger() with subsystem

**Limitations:** Log streaming is available for simulators and macOS apps. For physical devices, use Console.app.

---
