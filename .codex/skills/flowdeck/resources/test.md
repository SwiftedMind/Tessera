# test - Run Tests

Runs unit tests and UI tests for an Xcode project or workspace.

```bash
# Run all tests on iOS Simulator
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16"

# Run all tests on macOS
flowdeck test -w App.xcworkspace -s MyApp -D "My Mac"

# Run specific test class
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --only MyAppTests/LoginTests

# Run specific test method
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --only MyAppTests/LoginTests/testLogin

# Run specific test cases (comma-separated)
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --test-cases "MyAppTests/LoginTests/testLogin,MyAppTests/SignupTests/testSignup"

# Skip slow tests
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --skip MyAppTests/SlowIntegrationTests

# Run specific test targets
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --test-targets "UnitTests,IntegrationTests"

# Run a specific test plan by name (from the scheme)
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --plan "PassingOnly"

# Run a specific test plan by path (normalized to plan name)
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --plan "TestPlans/PassingOnly.xctestplan"

# Show test results as they complete
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --progress

# Clean output for file capture
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --streaming

# JSON output for CI/automation
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --json

# Verbose output with xcodebuild output
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --verbose

# Pass xcodebuild options (coverage, parallel testing, etc.)
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-enableCodeCoverage YES'
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-parallel-testing-enabled YES'
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-options='-retry-tests-on-failure'

# Pass xcodebuild environment variables
flowdeck test -w App.xcworkspace -s MyApp -S "iPhone 16" --xcodebuild-env='CI=true'
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj (REQUIRED unless init was run) |
| `-s, --scheme <name>` | Scheme name (auto-detected if only one) |
| `-S, --simulator <name>` | Simulator name/UDID (required for iOS/tvOS/watchOS) |
| `-D, --device <name>` | Device name/UDID (use "My Mac" for macOS) |
| `-C, --configuration <name>` | Build configuration (Debug/Release) |
| `-d, --derived-data-path <path>` | Custom derived data path |
| `--plan <name-or-path>` | Test plan name or `.xctestplan` path (uses plan name from filename) |
| `--test-targets <targets>` | Specific test targets to run (comma-separated) |
| `--test-cases <cases>` | Specific test cases to run (comma-separated, format: Target/Class/testMethod) |
| `--only <tests>` | Run only specific tests (format: Target/Class or Target/Class/testMethod) |
| `--skip <tests>` | Skip specific tests (format: Target/Class or Target/Class/testMethod) |
| `--progress` | Show test results as they complete (pass/fail per test) |
| `--streaming` | Stream clean formatted test results (no escape codes) |
| `--xcodebuild-options <args>` | Extra xcodebuild arguments |
| `--xcodebuild-env <vars>` | Xcodebuild environment variables |
| `-c, --config <path>` | Path to JSON config file |
| `-j, --json` | Output as JSON |
| `-v, --verbose` | Show raw xcodebuild test output |

**Test Filtering:**
The `--only` option supports:
- Full path: `MyAppTests/LoginTests/testValidLogin`
- Class name: `LoginTests` (runs all tests in that class)
- Method name: `testValidLogin` (runs all tests with that method name)

The `--test-cases` option accepts a comma-separated list of full identifiers.

**Test Plans:**
- `--plan` accepts a plan name or a `.xctestplan` path; the plan name is taken from the filename.
- If `--xcodebuild-options` already includes `-testPlan`, the CLI does not add another test plan.

---

## test discover - Discover Tests

Parses the Xcode project to find all test classes and methods without building.

```bash
# List all tests (human-readable)
flowdeck test discover -w App.xcworkspace -s MyScheme

# List all tests as JSON (for tooling)
flowdeck test discover -w App.xcworkspace -s MyScheme --json

# Filter tests by name
flowdeck test discover -w App.xcworkspace -s MyScheme --filter Login

# Include tests skipped in the scheme or test plan
flowdeck test discover -w App.xcworkspace -s MyScheme --include-skipped-tests
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj (also accepts `--ws`) |
| `-s, --scheme <name>` | Scheme name (also accepts `--sch`) |
| `-F, --filter <name>` | Filter tests by name (case-insensitive) |
| `-c, --config <path>` | Path to JSON config file (also accepts `--cfg`) |
| `-j, --json` | Output as JSON |
| `--include-skipped-tests` | Include tests marked as skipped in the scheme/test plan |

---

## test plans - List Test Plans

Lists test plans referenced by a scheme (no build required).

```bash
# List plans (human-readable)
flowdeck test plans -w App.xcworkspace -s MyScheme

# List plans as JSON (for tooling)
flowdeck test plans -w App.xcworkspace -s MyScheme --json
```

**Options:**
| Option | Description |
|--------|-------------|
| `-p, --project <path>` | Project directory |
| `-w, --workspace <path>` | Path to .xcworkspace or .xcodeproj (also accepts `--ws`) |
| `-s, --scheme <name>` | Scheme name (also accepts `--sch`) |
| `-c, --config <path>` | Path to JSON config file (also accepts `--cfg`) |
| `-j, --json` | Output as JSON |
| `-e, --examples` | Show usage examples |

---
