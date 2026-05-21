# Data Model and Sheet Schema

Primary reference: `setup/sheets-schema.md`

## Spreadsheet

- Name: `Fintrak Expenses`
- Tabs:
1. `Expenses`
2. `Categories`
3. `Summary`
4. `Config`

## Expenses Table (Primary Log)

Columns expected by workflows:
1. `Date`
2. `Merchant`
3. `Amount`
4. `Currency`
5. `Category`
6. `Type`
7. `Payment Method`
8. `Notes`
9. `Receipt URL`
10. `Source`
11. `Raw OCR`
12. `Timestamp`

Write sources:
- Workflow A writes photo-derived rows with `Source = Telegram Photo`.
- Workflow B writes text-derived rows with `Source = Telegram Text`.

## Computed / Reporting Behavior

- Summary and reporting commands read from the `Expenses` tab only.
- Monthly comparisons are computed in workflow code nodes at request time.
- Daily summary computes today vs yesterday and month-to-date totals.

## Categorization Model

- Rule-based keyword mapping with first-match-wins behavior.
- Default fallback category: `Other`.
- `b:` prefix forces `Type = Business`.

## Data Quality Observations

- Amount extraction from OCR uses largest numeric candidate, which is practical but may pick wrong totals for noisy receipts.
- Date parser primarily matches `DD/MM/YYYY`-style values and falls back to current date.
- `/undo` is a guided-manual undo (links user to sheet) rather than transactional delete in workflow.
