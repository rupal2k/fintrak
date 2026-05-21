# Workflow Map

## Workflow A - Receipt Photo Processor

Source: `n8n-workflows/workflow-a-receipt.json`

Flow:
1. Telegram message trigger.
2. Guard: allow only configured chat ID.
3. Check photo exists.
4. Fetch file path from Telegram API.
5. Download image.
6. Upload image to Google Drive receipts folder.
7. Send image to OCR.Space.
8. Parse OCR output:
- amount extraction (largest valid numeric match)
- date extraction with fallback to today
- merchant heuristics from first meaningful line
- payment method keyword detection
9. Categorize expense using keyword rules.
10. Append normalized row into `Expenses` sheet.
11. Reply to user with saved summary.

## Workflow B - Text Entry Processor

Source: `n8n-workflows/workflow-b-text.json`

Flow:
1. Telegram message trigger.
2. Guard: allow only configured chat ID.
3. Ensure plain text (not command, not photo).
4. Parse text:
- supports `y:` (yesterday)
- supports `b:` (force business type)
- supports optional payment method prefix (`cash`, `upi`, `card`, etc.)
- supports `k` shorthand (`5k` -> `5000`)
- supports merchant aliases (`sbux`, `swgy`, `amzn`, etc.)
5. Categorize via keyword rules.
6. Append row into `Expenses` sheet.
7. Reply with log confirmation.

## Workflow C - Command Handler

Source: `n8n-workflows/workflow-c-commands.json`

Supported command routing:
- `/summary`
- `/report`
- `/search`
- `/today`
- `/last`
- `/week`
- `/month`
- `/undo`
- fallback `/help`

Pattern:
1. Trigger + guard + command extraction.
2. Route to command-specific read node (Google Sheets).
3. Run command-specific code formatter.
4. Reply to Telegram in Markdown.

Notable behaviors:
- `/last N` clamps N between 1 and 20.
- `/month -1` supported for previous month.
- `/search keyword` scans merchant/notes/category.
- `/undo` returns latest expense details and Google Sheet link (manual delete path).

## Workflow D - Daily 9PM Summary

Source: `n8n-workflows/workflow-d-daily-cron.json`

Flow:
1. Cron trigger at `0 21 * * *` (9:00 PM local runtime timezone).
2. Read all expenses from sheet.
3. Build daily summary:
- personal total
- business total
- total with yesterday comparison
- top items and monthly running total
4. Send summary message to configured chat ID.

## Setup Provisioning Workflow

Source: `n8n-workflows/workflow-setup.json`

Purpose:
- Create Google Sheet (`Fintrak Expenses`).
- Create tabs (`Expenses`, `Categories`, `Summary`, `Config`).
- Create Drive folder (`Fintrak/Receipts`).
- Share sheet and folder with user email.
- Return IDs back to setup script for `.env` population.
