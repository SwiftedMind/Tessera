# ai - Manage FlowDeck Skill Packs for Agents

Use `flowdeck ai` to install or remove the FlowDeck skill pack for supported AI agents.

#### ai install-skill

Install the FlowDeck skill pack for an agent.

```bash
flowdeck ai install-skill --agent codex --mode user
flowdeck ai install-skill --agent claude --mode project
flowdeck ai install-skill --agent codex --mode user --json
flowdeck ai install-skill --agent codex --mode user --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `--agent <agent>` | Agent name: `codex`, `claude`, `opencode`, or `cursor` |
| `--mode <mode>` | Install mode: `user` or `project` |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### ai uninstall-skill

Remove the FlowDeck skill pack for an agent.

```bash
flowdeck ai uninstall-skill --agent codex --mode user
flowdeck ai uninstall-skill --agent claude --mode project
flowdeck ai uninstall-skill --agent codex --mode user --json
flowdeck ai uninstall-skill --agent codex --mode user --examples
```

**Options:**
| Option | Description |
|--------|-------------|
| `--agent <agent>` | Agent name: `codex`, `claude`, `opencode`, or `cursor` |
| `--mode <mode>` | Uninstall mode: `user` or `project` |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

**When to Use:**
- Reinstall the FlowDeck skill pack after a CLI upgrade
- Remove the FlowDeck skill pack from a repo or user profile
- Switch between user-wide and project-local skill installation

---
