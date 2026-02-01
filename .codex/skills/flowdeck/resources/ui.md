# ui - UI Automation (iOS Simulator Only)

UI automation is a top-level command group. Use `flowdeck ui simulator` for screen capture, element queries, gestures, taps, typing, assertions, and app control on iOS simulators. Do not use `flowdeck simulator ui`. Commands are kebab-case (for example: `double-tap`, `hide-keyboard`, `open-url`, `clear-state`).

**Guidance:**
- Prefer accessibility identifiers; use `--by-id` for taps, finds, and assertions.
- Use `flowdeck ui simulator screen --tree --json` for structure-only; add `--optimize` if you need a screenshot.
- Avoid screenshots during navigation; capture images only for design comparison or layout validation.
- For agent loops, use `flowdeck ui simulator session start` and read `latest.json`, `latest.jpg`, and `latest-tree.json`.
- For off-screen elements, `flowdeck ui simulator scroll --until "id:yourElement"` before tapping.

#### ui simulator screen

Capture a screenshot and accessibility tree from a simulator.

```bash
# Screenshot + accessibility tree (JSON)
flowdeck ui simulator screen --json

# Screenshot only, optimized for size
flowdeck ui simulator screen --output ./screen.png --optimize

# Accessibility tree only
flowdeck ui simulator screen --tree --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output path for screenshot |
| `-u, --udid <udid>` | Simulator UDID (uses session simulator if not specified) |
| `-j, --json` | Output as JSON |
| `--optimize` | Optimize screenshot for agents (smaller size) |
| `--tree` | Accessibility tree only (no screenshot) |
| `-v, --verbose` | Show detailed output |

#### ui simulator session

Start or stop a UI automation capture session. Requires a booted simulator. Starting a session stops any active session and captures tree + screenshot every 500ms into `./.flowdeck/automation/sessions/<session-short-id>`. Screenshots are JPEG at 50% quality and only written when the tree changes. JSON output includes the session directory, files, and latest pointers.

```bash
flowdeck ui simulator session start
flowdeck ui simulator session stop
```

#### ui simulator record

Record simulator video.

```bash
flowdeck ui simulator record --output ./demo.mov
flowdeck ui simulator record --duration 20 --codec hevc --force
```

**Options:**
| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output path for video (.mov) |
| `-t, --duration <seconds>` | Recording duration (default: 10) |
| `--codec <codec>` | Video codec: h264 or hevc |
| `--force` | Overwrite output file if it exists |
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator tap

Tap an element by label or accessibility identifier, or tap coordinates.

```bash
flowdeck ui simulator tap "Log In"
flowdeck ui simulator tap "login_button" --by-id
flowdeck ui simulator tap --point 120,340
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element label/ID to tap (or use --point) |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Tap at coordinates (x,y) |
| `-d, --duration <seconds>` | Hold duration for long press |
| `-u, --udid <udid>` | Simulator UDID |
| `--by-id` | Treat target as accessibility identifier |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator double-tap

Double tap an element or coordinates.

```bash
flowdeck ui simulator double-tap "Like"
flowdeck ui simulator double-tap "like_button" --by-id
flowdeck ui simulator double-tap --point 160,420
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element label/ID to double tap (or use --point) |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Coordinates to double tap (x,y) |
| `-u, --udid <udid>` | Simulator UDID |
| `--by-id` | Search by accessibility identifier |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator type

Type text into the focused element.

```bash
flowdeck ui simulator type "hello@example.com"
flowdeck ui simulator type "hunter2" --mask
flowdeck ui simulator type "New Value" --clear
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<text>` | Text to type |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `--clear` | Clear field before typing |
| `--mask` | Mask text in output |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator swipe

Swipe on the screen.

```bash
flowdeck ui simulator swipe up
flowdeck ui simulator swipe --from 120,700 --to 120,200 --duration 0.5
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<direction>` | Swipe direction (up, down, left, right) |

**Options:**
| Option | Description |
|--------|-------------|
| `--from <point>` | Start point (x,y) |
| `--to <point>` | End point (x,y) |
| `--duration <seconds>` | Swipe duration (default: 0.3) |
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator scroll

Scroll content (gentler than swipe).

```bash
flowdeck ui simulator scroll --direction DOWN
flowdeck ui simulator scroll --until "Settings" --timeout 10000
flowdeck ui simulator scroll --until "id:yourElement"
```

**Options:**
| Option | Description |
|--------|-------------|
| `-d, --direction <direction>` | Scroll direction (UP, DOWN, LEFT, RIGHT) |
| `-s, --speed <speed>` | Scroll speed 0-100 (default: 40) |
| `--until <target>` | Scroll until element becomes visible |
| `--timeout <ms>` | Timeout in ms for --until (default: 20000) |
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator back

Navigate back.

```bash
flowdeck ui simulator back
```

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator pinch

Pinch to zoom in or out.

```bash
flowdeck ui simulator pinch out
flowdeck ui simulator pinch in --scale 0.6 --point 200,400
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<direction>` | Pinch direction (in for zoom out, out for zoom in) |

**Options:**
| Option | Description |
|--------|-------------|
| `--scale <scale>` | Scale factor (default: 2.0 for out, 0.5 for in) |
| `-p, --point <point>` | Center point for pinch (x,y) |
| `--duration <seconds>` | Pinch duration (default: 0.5) |
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator gesture

Perform a preset gesture (tap, double-tap, long-press, swipe, scroll, pinch) at the center or a specific point.

```bash
flowdeck ui simulator gesture tap
flowdeck ui simulator gesture double-tap
flowdeck ui simulator gesture long-press --duration 1.5
flowdeck ui simulator gesture swipe-up
flowdeck ui simulator gesture scroll-down
flowdeck ui simulator gesture pinch-in
flowdeck ui simulator gesture pinch-out --scale 3.0
flowdeck ui simulator gesture tap --point 200,400
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<name>` | tap, double-tap, long-press, swipe-up/down/left/right, scroll-up/down, pinch-in/out |

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --point <point>` | Center point for tap/long-press/pinch (x,y) |
| `--duration <seconds>` | Duration in seconds (long-press/swipe; also influences scroll speed) |
| `--scale <scale>` | Pinch scale (default: 2.0 for out, 0.5 for in) |
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator find

Find an element and return its info/text.

```bash
flowdeck ui simulator find "Settings"
flowdeck ui simulator find "settings_button" --by-id
flowdeck ui simulator find "button" --by-role
flowdeck ui simulator find "Log" --contains
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element to find (label, ID, or role) |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `--by-id` | Search by accessibility identifier |
| `--by-role` | Search by element role (button, textfield, etc.) |
| `--contains` | Match elements containing the text |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator wait

Wait for element conditions.

```bash
flowdeck ui simulator wait "Loading..."
flowdeck ui simulator wait "Submit" --enabled --timeout 15
flowdeck ui simulator wait "Toast" --gone
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<target>` | Element to wait for |

**Options:**
| Option | Description |
|--------|-------------|
| `-t, --timeout <seconds>` | Timeout in seconds (default: 30) |
| `--poll <ms>` | Poll interval in ms (default: 500) |
| `-u, --udid <udid>` | Simulator UDID |
| `--gone` | Wait for element to disappear |
| `--enabled` | Wait for element to be enabled |
| `--stable` | Wait for element to be stable (not moving) |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator assert

Assert element conditions.

```bash
flowdeck ui simulator assert visible "Profile"
flowdeck ui simulator assert hidden "Spinner"
flowdeck ui simulator assert enabled "Submit"
flowdeck ui simulator assert disabled "Continue"
flowdeck ui simulator assert text "Welcome" --expected "Hello"
```

**Subcommands:**
| Subcommand | Description |
|------------|-------------|
| `visible <target>` | Assert element is visible |
| `hidden <target>` | Assert element is hidden |
| `enabled <target>` | Assert element is enabled |
| `disabled <target>` | Assert element is disabled |
| `text <target>` | Assert element contains expected text |

**Options (all subcommands):**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `--by-id` | Search by accessibility identifier |

**Options (text subcommand only):**
| Option | Description |
|--------|-------------|
| `--expected <text>` | Expected text content |
| `--contains` | Check if text contains expected |

#### ui simulator erase

Erase text from the focused field.

```bash
flowdeck ui simulator erase
flowdeck ui simulator erase --characters 5
```

**Options:**
| Option | Description |
|--------|-------------|
| `-c, --characters <count>` | Number of characters to erase (default: all) |
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator hide-keyboard

Hide the on-screen keyboard.

```bash
flowdeck ui simulator hide-keyboard
```

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator key

Press keyboard key codes.

```bash
flowdeck ui simulator key 40
flowdeck ui simulator key --sequence 40,42
flowdeck ui simulator key 42 --hold 0.2
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<keycode>` | HID keycode (e.g., 40 for Enter, 42 for Backspace) |

**Options:**
| Option | Description |
|--------|-------------|
| `--sequence <codes>` | Comma-separated keycodes |
| `--hold <seconds>` | Hold duration in seconds |
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator open-url

Open a URL or deep link in the simulator.

```bash
flowdeck ui simulator open-url https://example.com
flowdeck ui simulator open-url myapp://path
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<url>` | URL to open |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |

#### ui simulator clear-state

Clear app data/state from the simulator.

```bash
flowdeck ui simulator clear-state com.example.app
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<bundle-id>` | Bundle identifier of app to clear |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |

#### ui simulator rotate

Rotate simulator orientation.

```bash
flowdeck ui simulator rotate landscape
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<orientation>` | portrait, landscape, landscapeRight, landscapeLeft, portraitUpsideDown |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |

#### ui simulator button

Press a hardware button.

```bash
flowdeck ui simulator button home
flowdeck ui simulator button lock --hold 1.0
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<button>` | home, lock, siri, applepay, volumeup, volumedown |

**Options:**
| Option | Description |
|--------|-------------|
| `--hold <seconds>` | Hold duration in seconds |
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator touch down

Touch down at coordinates.

```bash
flowdeck ui simulator touch down 120,340
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<point>` | Coordinates (x,y) in screen points |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### ui simulator touch up

Touch up at coordinates.

```bash
flowdeck ui simulator touch up 120,340

#### UI Timing Tuning

Set these environment variables when you need to slow input or improve stability:

- `FLOWDECK_HID_STABILIZATION_MS` Extra settle time between HID events
- `FLOWDECK_TYPE_DELAY_MS` Per-character typing delay
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<point>` | Coordinates (x,y) in screen points |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show detailed output |

#### simulator erase

Erases all content and settings from a simulator, resetting it to factory defaults. The simulator must be shutdown before erasing.

```bash
flowdeck simulator erase <udid>
```

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |

**When to Use:**
- To test fresh app installation
- To clear corrupted simulator state
- Before running UI tests that need a clean slate

#### simulator clear-cache

Clears simulator caches to free disk space and resolve caching issues.

```bash
flowdeck simulator clear-cache
```

**Options:**
| Option | Description |
|--------|-------------|
| `-v, --verbose` | Show command output |

**When to Use:**
- When simulators are using too much disk space
- When experiencing strange caching behavior
- After updating Xcode

#### simulator create

Creates a new simulator with the specified device type and runtime.

```bash
# Create an iPhone 16 Pro simulator with iOS 18.1
flowdeck simulator create --name "My iPhone 16" --device-type "iPhone 16 Pro" --runtime "iOS 18.1"

# List available device types and runtimes first
flowdeck simulator device-types
flowdeck simulator runtime list
```

**Options:**
| Option | Description |
|--------|-------------|
| `-n, --name <name>` | Name for the new simulator (REQUIRED) |
| `--device-type <type>` | Device type, e.g., 'iPhone 16 Pro' (REQUIRED) |
| `--runtime <runtime>` | Runtime, e.g., 'iOS 18.1' or 'iOS-18-1' (REQUIRED) |
| `-v, --verbose` | Show command output |
| `-j, --json` | Output as JSON |

#### simulator delete

Deletes a simulator by UDID or name.

```bash
# Delete by UDID
flowdeck simulator delete <udid>

# Delete by name
flowdeck simulator delete "iPhone 15"

# Delete all unavailable simulators
flowdeck simulator delete --unavailable
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<identifier>` | Simulator UDID or name (ignored with --unavailable) |

**Options:**
| Option | Description |
|--------|-------------|
| `--unavailable` | Delete all unavailable simulators |
| `-v, --verbose` | Show command output |

#### simulator prune

Deletes simulators that have never been used, freeing up disk space.

```bash
# Preview what would be deleted
flowdeck simulator prune --dry-run

# Delete unused simulators
flowdeck simulator prune
```

**Options:**
| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be deleted without deleting |
| `-v, --verbose` | Show verbose output |
| `-j, --json` | Output as JSON |

#### simulator device-types

Lists all simulator device types available for creating new simulators.

```bash
flowdeck simulator device-types
flowdeck simulator device-types --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-P, --platform <platform>` | Filter by platform (iOS, tvOS, watchOS, visionOS) |
| `--json` | Output as JSON |

#### simulator location set

Set simulator location coordinates.

```bash
flowdeck simulator location set 37.7749,-122.4194
flowdeck simulator location set 37.7749,-122.4194 --udid <udid>
flowdeck simulator location set 37.7749,-122.4194 --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<lat,lon>` | Coordinates in `latitude,longitude` format |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID (defaults to first booted simulator) |
| `-j, --json` | Output as JSON |

#### simulator media add

Add media to a simulator (photos or videos).

```bash
flowdeck simulator media add /path/to/photo.jpg
flowdeck simulator media add /path/to/video.mov --udid <udid>
flowdeck simulator media add /path/to/photo.jpg --json
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `<file>` | Path to media file |

**Options:**
| Option | Description |
|--------|-------------|
| `-u, --udid <udid>` | Simulator UDID (defaults to first booted simulator) |
| `-j, --json` | Output as JSON |

---
