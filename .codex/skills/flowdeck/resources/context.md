# context - Discover Project Structure

Inspect a project and return the workspace, schemes, build configurations, simulators, and derived data path.

```bash
flowdeck context
flowdeck context --json
flowdeck context --project /path/to/project
flowdeck context --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**Returns:**
- Workspace path
- Available schemes
- Build configurations
- Available simulators
- Derived data path

---
