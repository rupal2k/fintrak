# Work Done Timeline

Source: `git log` (latest commits through `2026-05-10`).

## 2026-05-08 - Initial Build

- Repo initialized with base docs/specs.
- Added `docker-compose.yml`.
- Added core automation workflows:
  - receipt processor
  - text processor
  - command handler
  - daily cron summary
- Added setup documentation baseline.

## 2026-05-09 - Major Productization Pass

- Added setup workflow for automatic Google Sheet and Drive provisioning.
- Added credential templates for n8n imports.
- Added full 5-phase setup wizards for:
  - Windows PowerShell (`setup.ps1`)
  - Mac/Linux bash (`setup.sh`)
  - Android Termux (`setup-android.sh`)
- Added `setup.bat` launcher and cross-platform improvements.
- Upgraded workflows with smarter parsing:
  - shorthand values (`5k`)
  - date/type prefixes (`y:`, `b:`)
  - more command coverage and month comparison.
- Rewrote README and setup guides for non-technical users.
- Updated troubleshooting and command documentation.

## 2026-05-10 - Cleanup and Hardening

- Security cleanup commit removing tracked `CLAUDE.md` and ignore updates.
- Added `.claude` ignore maintenance.
- README media refresh.

## Current State Summary

- Architecture is functionally complete for single-user self-hosted expense tracking.
- Core feature set is centered around Telegram-first UX with Google Sheets as source of truth.
- Setup UX has been optimized heavily for non-technical users across platforms.
