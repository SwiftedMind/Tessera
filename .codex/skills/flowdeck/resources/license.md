# license - Manage License

Activate, check, or deactivate your FlowDeck license.

#### license status

Displays your current license status, including plan type, expiration, and number of activations used.

```bash
# Check license status
flowdeck license status

# Get JSON output for scripting
flowdeck license status --json
```

#### license trial

Starts a free 7-day trial of FlowDeck. No credit card required.

```bash
# Start free trial (interactive - prompts for name and email)
flowdeck license trial

# JSON output
flowdeck license trial --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `--json` | Output as JSON |

**Notes:**
- You will be prompted to enter your name and email address
- Trial is 7 days with full access to all features
- After trial expires, visit flowdeck.studio/pricing to purchase

#### license activate

Activates your FlowDeck license key on this machine.

```bash
flowdeck license activate ABCD1234-EFGH5678-IJKL9012-MNOP3456

# JSON output
flowdeck license activate ABCD1234-EFGH5678-IJKL9012-MNOP3456 --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<key>` | License key (REQUIRED) |

**CI/CD:** For CI/CD, set `FLOWDECK_LICENSE_KEY` environment variable instead.

#### license deactivate

Deactivates your license on this machine, freeing up an activation slot.

```bash
flowdeck license deactivate

# JSON output
flowdeck license deactivate --json
```

Use this before moving your license to a different machine.

---
