# context - Discover Project Structure

Shows all project information needed to run build/run/test commands. **This is typically the FIRST command to run in a new project.**

```bash
# Human-readable output
flowdeck context

# JSON output (for parsing/automation)
flowdeck context --json

# Specific project directory
flowdeck context --project /path/to/project
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `--json` | Output as JSON |

**Returns:**
- Workspace path (needed for --workspace parameter)
- Available schemes (use with --scheme)
- Build configurations (Debug, Release, etc.)
- Available simulators (use with --simulator)

---
