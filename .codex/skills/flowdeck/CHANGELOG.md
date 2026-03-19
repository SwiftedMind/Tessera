# FlowDeck Skill Pack Changelog

## 1.11.1 - 2026-03-19
- Bumped FlowDeck skill pack version to 1.11.1.


## 1.11.0 - 2026-03-19
- Bumped FlowDeck skill pack version to 1.11.0.


## 1.10.3 - 2026-03-11
- Added UI automation guardrails to stop agents from inventing unsupported FlowDeck flags, aliases, and key names.
- Added browser-specific guidance: use the browser app's own address bar and controls, not `ui simulator open-url`, when validating web navigation.
- Changed stale-session recovery guidance to restart the session and continue with the new `latest_*` paths instead of falling back to one-off `screen` captures.

## 1.10.2 - 2026-03-11
- Audited the FlowDeck skill pack against the current CLI command surface and refreshed outdated command guidance.
- Added dedicated references for top-level `uninstall` and `ai` commands.
- Moved package resolution guidance to the standalone `package-resolution.md` reference and kept `SKILL.md` as a pointer only.
- Reworked UI automation guidance to match current `ui simulator` commands, removed duplicated simulator docs from `ui.md`, and synced simulator coverage across both skill packs.
- Normalized smaller command references (`apps`, `logs`, `stop`, `context`, `device`, `test`, and `project`) to current flags/examples.

## 1.10.1 - 2026-03-05
- Bumped FlowDeck skill pack version to 1.10.1.

## 1.10.0 - 2026-03-04
- Bumped FlowDeck skill pack version to 1.10.0.

## 1.9.3 - 2026-03-02
- Bumped FlowDeck skill pack version to 1.9.3.

## 1.9.2 - 2026-03-02
- Bumped FlowDeck skill pack version to 1.9.2.

## 1.9.1 - 2026-02-27
- Bumped FlowDeck skill pack version to 1.9.1.

## 1.9.0 - 2026-02-26
- Synced FlowDeck skill pack with CLI 1.9.0.
- Bumped FlowDeck skill pack version to 1.9.0.

## 1.8.0 - 2026-02-07
- Reorganized and expanded doc-bot documentation.
- Split doc-bot docs by product surface: Extension, CLI, and macOS app.
- Reviewed doc-bot coverage against code and filled missing implementation details.
- Bumped FlowDeck skill pack version to 1.8.0.

## 1.7.3 - 2026-02-04
- CLI releases now publish the matching skill pack automatically.
- Release flow removes skill pack backups and respects `--force` preflight.
