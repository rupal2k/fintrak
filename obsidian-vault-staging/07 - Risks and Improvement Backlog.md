# Risks and Improvement Backlog

## Current Risks

1. OCR uncertainty on noisy receipts
- Largest-number heuristic can misclassify subtotal/tax/total.

2. Undo is manual, not atomic
- `/undo` returns a sheet link and depends on user action.

3. Rule duplication
- Category logic exists separately in workflow A and B code nodes.

4. Date parsing edge cases
- OCR date extraction may mis-handle non-standard formats.

5. Single-user assumption
- Access model is anchored to one Telegram chat ID.

## Improvement Backlog

1. Centralize categorization rules
- Store in single JSON resource and load in both workflows.

2. Add confidence scoring
- Return low-confidence receipts as "Needs Review" before save.

3. Implement transactional undo
- Add delete-last-row workflow action with confirmation.

4. Add structured test fixtures
- Build sample OCR/text payload tests for parse and categorize functions.

5. Add observability
- Create lightweight execution/error dashboard sheet or notification channel.

6. Add backup/export automation
- Scheduled copy/export of expenses for disaster recovery.
