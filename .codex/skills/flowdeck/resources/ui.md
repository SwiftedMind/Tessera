# ui - UI Automation (iOS Simulator Only)

UI automation is a top-level command group. Use `flowdeck ui simulator` for screen capture, element queries, gestures, taps, typing, assertions, and app control on iOS simulators. Do not use `flowdeck simulator ui`. Commands are kebab-case (for example: `double-tap`, `hide-keyboard`, `open-url`, `clear-state`).

**Guidance:**
- Always pass `-S <name-or-udid>` (or `--simulator`) on every `flowdeck ui simulator ...` command in automation. It accepts either a simulator name (for example, `"iPhone 16"`) or a raw UDID.
- **Start a session BEFORE any UI work**: `flowdeck ui simulator session start -S "iPhone 16" --json`. Parse the JSON output to get the `latest_screenshot` and `latest_tree` file paths. Use your Read tool on those paths to see the screen and inspect elements.
- **Verify after EVERY action**: after each tap/type/swipe, wait about 1 second, then re-read `latest_screenshot` or `latest_tree`. Never chain actions without checking the result.
- **If a session looks stale, restart it**: run `flowdeck ui simulator session start -S "iPhone 16" --json` again, replace the saved `latest_*` paths, and continue with the restarted session. Do not switch to `screen` as the first response to suspected session staleness.
- **Use the app's own UI when testing browser apps**: do not use `flowdeck ui simulator open-url` to validate website loading or browser navigation. Use the browser's address/search field and in-app controls. Reserve `open-url` for explicit deep-link or system handoff tests.
- **Do not invent FlowDeck syntax**: if you are unsure about flags, keycodes, or subcommand arguments, run `flowdeck ui simulator <subcommand> --help` first. Do not guess unsupported flags like `--x/--y` or string key names.
- Prefer accessibility identifiers and `--by-id` whenever the app exposes them.
- For off-screen elements, use `flowdeck ui simulator scroll --until "id:yourElement" -S "iPhone 16"` before tapping.
- Coordinate-based commands accept `--geometry points`. Do not scale by @2x/@3x or device resolution; FlowDeck coordinates already match point-normalized screenshots.
- Most subcommands support `-j, --json`, `-v, --verbose`, and `-e, --examples`. If you are unsure about current flags, run `flowdeck ui simulator <subcommand> --help`.

#### ui simulator screen

Capture a screenshot and accessibility tree from a simulator.

```bash
flowdeck ui simulator screen -S "iPhone 16" --json
flowdeck ui simulator screen -S "iPhone 16" --output ./screen.png --optimize
flowdeck ui simulator screen -S "iPhone 16" --tree --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output path for screenshot |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |
| `--optimize` | Optimize screenshot for agents (smaller size) |
| `--tree` | Accessibility tree only (no screenshot) |

**Notes:**
- `screen` reports coordinates in points. JSON includes point and pixel dimensions when available.
- If `-S` is omitted, FlowDeck falls back to the session/default simulator. Agents should not rely on that.
- `screen` is a fallback for explicit one-off captures, not the default way to recover from a possibly stale session.

#### ui simulator session

Start or stop a background capture session. Requires a booted simulator. `session start` stops any active session first and writes captures into `./.flowdeck/automation/sessions/<session-short-id>/`.

```bash
flowdeck ui simulator session start -S "iPhone 16" --json
flowdeck ui simulator session stop -S "iPhone 16"
```

**Options (`session start`):**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |
| `--interval-ms <ms>` | Capture interval in milliseconds (default: `500`) |
| `--retention-seconds <seconds>` | Retention window in seconds (default: `60`) |

**Session Files:**
- `latest.jpg` points to the latest screenshot.
- `latest-tree.json` points to the latest accessibility tree.
- `latest.json` points to the latest capture metadata.
- JSON output from `session start` includes absolute paths for the session directory and latest files.

**If the session appears stale:**
1. Wait briefly and re-read the same `latest.jpg` / `latest-tree.json` paths.
2. If they still do not reflect an obvious UI change, run `flowdeck ui simulator session start -S "iPhone 16" --json` again.
3. Save the new `latest_screenshot`, `latest_tree`, and `latest` paths from the restarted session.
4. Continue with the restarted session. Only fall back to `screen` if the restarted session is still wrong.

#### ui simulator record

Record simulator video.

```bash
flowdeck ui simulator record -S "iPhone 16" --output ./demo.mov
flowdeck ui simulator record -S "iPhone 16" --duration 20 --codec hevc --force
```

**Options:**
| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output path for video (`.mov`) |
| `-t, --duration <seconds>` | Recording duration in seconds |
| `--codec <codec>` | `h264` or `hevc` |
| `--force` | Overwrite an existing output file |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator find

Find an element and return its info/text.

```bash
flowdeck ui simulator find "Settings" -S "iPhone 16"
flowdeck ui simulator find "settings_button" -S "iPhone 16" --by-id
flowdeck ui simulator find "button" -S "iPhone 16" --by-role
flowdeck ui simulator find "Log" -S "iPhone 16" --contains
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element to find (label, ID, or role) |

**Options:**
| Option | Description |
|--------|-------------|
| `--by-id` | Search by accessibility identifier |
| `--by-role` | Search by element role (for example `button`, `textField`) |
| `--contains` | Match elements containing the text |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator tap

Tap an element by label or accessibility identifier, or tap coordinates.

```bash
flowdeck ui simulator tap "Log In" -S "iPhone 16"
flowdeck ui simulator tap "login_button" -S "iPhone 16" --by-id
flowdeck ui simulator tap --point 120,340 -S "iPhone 16"
flowdeck ui simulator tap --point 120,340 --geometry points -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element label/ID to tap (or use `--point`) |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Tap at coordinates (`x,y`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `-d, --duration <seconds>` | Hold duration for a long press |
| `--by-id` | Treat target as an accessibility identifier |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator double-tap

Double tap an element or coordinates.

```bash
flowdeck ui simulator double-tap "Like" -S "iPhone 16"
flowdeck ui simulator double-tap "like_button" -S "iPhone 16" --by-id
flowdeck ui simulator double-tap --point 160,420 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element label/ID to double tap (or use `--point`) |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Coordinates to double tap (`x,y`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `--by-id` | Search by accessibility identifier |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator type

Type text into the focused element.

```bash
flowdeck ui simulator type "hello@example.com" -S "iPhone 16"
flowdeck ui simulator type "hunter2" -S "iPhone 16" --mask
flowdeck ui simulator type "New Value" -S "iPhone 16" --clear
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<text>` | Text to type |

**Options:**
| Option | Description |
|--------|-------------|
| `--clear` | Clear the field before typing |
| `--mask` | Mask the typed text in terminal output and JSON |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator swipe

Swipe on the screen.

```bash
flowdeck ui simulator swipe up -S "iPhone 16"
flowdeck ui simulator swipe --from 120,700 --to 120,200 --duration 0.5 -S "iPhone 16"
flowdeck ui simulator swipe down --distance 0.25 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<direction>` | Swipe direction: `up`, `down`, `left`, or `right` |

**Options:**
| Option | Description |
|--------|-------------|
| `--from <point>` | Start point (`x,y`) |
| `--to <point>` | End point (`x,y`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `--duration <seconds>` | Swipe duration in seconds (default: `0.3`) |
| `--distance <fraction>` | Swipe distance as a fraction of the screen (`0.05`-`0.95`, default: `0.4`) |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator scroll

Scroll content more gently than `swipe`.

```bash
flowdeck ui simulator scroll --direction DOWN -S "iPhone 16"
flowdeck ui simulator scroll --until "Settings" --timeout 10000 -S "iPhone 16"
flowdeck ui simulator scroll --until "id:yourElement" -S "iPhone 16"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-d, --direction <direction>` | Scroll direction by content: `UP`, `DOWN`, `LEFT`, `RIGHT` |
| `-s, --speed <speed>` | Scroll speed `0`-`100` (default: `40`) |
| `--distance <fraction>` | Scroll distance as a fraction of the screen (`0.05`-`0.95`, default: `0.2`) |
| `--until <target>` | Scroll until the target becomes visible |
| `--timeout <ms>` | Timeout for `--until` in milliseconds |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator back

Navigate back with the simulator back gesture.

```bash
flowdeck ui simulator back -S "iPhone 16"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator pinch

Pinch to zoom in or out.

```bash
flowdeck ui simulator pinch out -S "iPhone 16"
flowdeck ui simulator pinch in --scale 0.6 --point 200,400 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<direction>` | `in` for zoom out, `out` for zoom in |

**Options:**
| Option | Description |
|--------|-------------|
| `--scale <scale>` | Scale factor (defaults: `2.0` for `out`, `0.5` for `in`) |
| `-p, --point <point>` | Pinch center point (`x,y`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `--duration <seconds>` | Pinch duration in seconds |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator wait

Wait for an element condition.

```bash
flowdeck ui simulator wait "Loading..." -S "iPhone 16"
flowdeck ui simulator wait "Submit" --enabled --timeout 15 -S "iPhone 16"
flowdeck ui simulator wait "Toast" --gone -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element to wait for |

**Options:**
| Option | Description |
|--------|-------------|
| `-t, --timeout <seconds>` | Timeout in seconds (default: `30`) |
| `--poll <ms>` | Poll interval in milliseconds (default: `500`) |
| `--gone` | Wait for the element to disappear |
| `--enabled` | Wait for the element to become enabled |
| `--stable` | Wait for the element to stop moving |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator assert

Assert element conditions.

```bash
flowdeck ui simulator assert visible "Profile" -S "iPhone 16"
flowdeck ui simulator assert hidden "Spinner" -S "iPhone 16"
flowdeck ui simulator assert enabled "Submit" -S "iPhone 16"
flowdeck ui simulator assert disabled "Continue" -S "iPhone 16"
flowdeck ui simulator assert text "Welcome" -S "iPhone 16" --expected "Hello"
```

**Subcommands:**
| Subcommand | Description |
|------------|-------------|
| `visible <target>` | Assert the element is visible |
| `hidden <target>` | Assert the element is hidden |
| `enabled <target>` | Assert the element is enabled |
| `disabled <target>` | Assert the element is disabled |
| `text <target>` | Assert the element text matches |

**Common Options:**
| Option | Description |
|--------|-------------|
| `--by-id` | Search by accessibility identifier |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

**Text Options:**
| Option | Description |
|--------|-------------|
| `--expected <text>` | Expected text value |
| `--contains` | Check whether the text contains the expected value |

#### ui simulator erase

Erase text from the focused field.

```bash
flowdeck ui simulator erase -S "iPhone 16"
flowdeck ui simulator erase --characters 5 -S "iPhone 16"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-c, --characters <count>` | Number of characters to erase (omit to clear all) |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator hide-keyboard

Hide the on-screen keyboard.

```bash
flowdeck ui simulator hide-keyboard -S "iPhone 16"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator key

Send HID keyboard key codes.

```bash
flowdeck ui simulator key 40 -S "iPhone 16"
flowdeck ui simulator key --sequence 40,42 -S "iPhone 16"
flowdeck ui simulator key 42 --hold 0.2 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<keycode>` | HID keycode (for example `40` for Enter, `42` for Backspace) |

**Options:**
| Option | Description |
|--------|-------------|
| `--sequence <codes>` | Comma-separated HID keycodes |
| `--hold <seconds>` | Hold duration in seconds |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

**Notes:**
- `key` expects numeric HID keycodes, not string names. For example, Enter/Return is `40`.
- If you are unsure which keycode you need, run `flowdeck ui simulator key --help` before retrying.

#### ui simulator open-url

Open a URL or deep link in the simulator.

```bash
flowdeck ui simulator open-url https://example.com -S "iPhone 16"
flowdeck ui simulator open-url myapp://path -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<url>` | URL or deep link to open |

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

**Notes:**
- `open-url` hands the URL to the simulator/OS. It may open Safari or another registered app.
- Do not use `open-url` to validate browser-app navigation. Use the browser's own address bar and controls instead.

#### ui simulator clear-state

Clear app data/state from the simulator.

```bash
flowdeck ui simulator clear-state com.example.app -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<bundle-id>` | Bundle identifier for the app to reset |

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator rotate

Rotate with a two-finger gesture.

```bash
flowdeck ui simulator rotate 90 -S "iPhone 16"
flowdeck ui simulator rotate -45 --point 200,400 --radius 80 --duration 0.5 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<angle>` | Rotation angle in degrees (positive = clockwise, negative = counterclockwise) |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Rotation center point (`x,y`) |
| `--radius <radius>` | Radius in points for the two-finger rotation (default: `80`) |
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `--duration <seconds>` | Rotate duration in seconds |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator set-appearance

Set the simulator appearance to light or dark mode.

```bash
flowdeck ui simulator set-appearance light -S "iPhone 16"
flowdeck ui simulator set-appearance dark -S "iPhone 16"
flowdeck ui simulator set-appearance dark -S "iPhone 16" --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<appearance>` | Appearance style: `light` or `dark` |

**Options:**
| Option | Description |
|--------|-------------|
| `-S, --simulator <name-or-udid>` | Simulator name or UDID (defaults to booted simulator) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

#### ui simulator button

Press a hardware button.

```bash
flowdeck ui simulator button home -S "iPhone 16"
flowdeck ui simulator button lock --hold 1.0 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<button>` | `home`, `lock`, `siri`, `applepay`, `volumeup`, or `volumedown` |

**Options:**
| Option | Description |
|--------|-------------|
| `--hold <seconds>` | Hold duration in seconds |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator touch down

Touch down at coordinates.

```bash
flowdeck ui simulator touch down 120,340 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<point>` | Point coordinates (`x,y`) in screen points |

**Options:**
| Option | Description |
|--------|-------------|
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### ui simulator touch up

Touch up at coordinates.

```bash
flowdeck ui simulator touch up 120,340 -S "iPhone 16"
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<point>` | Point coordinates (`x,y`) in screen points |

**Options:**
| Option | Description |
|--------|-------------|
| `--geometry <geometry>` | Coordinate geometry (`points` only) |
| `-S, --simulator <name-or-udid>` | Simulator name or UDID |

#### UI Timing Tuning

Set these environment variables when you need to slow input or improve stability:

- `FLOWDECK_HID_STABILIZATION_MS` adds settle time between HID events (default: `25`)
- `FLOWDECK_TYPE_DELAY_MS` adds per-character typing delay (default: `20`)

---
