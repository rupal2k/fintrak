# Commands and Parsing Rules

## Text Logging Grammar

Supported examples:
- `250 starbucks coffee`
- `b:500 vendor payment`
- `y:300 auto`
- `cash 1200 electricity bill`
- `5k swgy dinner`

Parsing stages (Workflow B):
1. Detect `y:` prefix -> use yesterday date.
2. Detect `b:` prefix -> force business type.
3. Detect payment method token (first word lookup).
4. Strip currency symbol prefix.
5. Parse amount (`N`, `N.NN`, `N,NNN`, `Nk`).
6. Parse merchant token + alias normalization.
7. Remaining text becomes notes.

## Merchant Aliases

Examples from workflow code:
- `sbux` -> `Starbucks`
- `swgy` -> `Swiggy`
- `zmto` -> `Zomato`
- `amzn` -> `Amazon`
- `mcds` -> `McDonalds`

## Slash Commands

- `/summary` monthly total split + category breakdown
- `/report` full month category totals
- `/search <term>` recent matching expenses
- `/today` itemized today list + totals
- `/last [N]` recent N expenses (default 5, max 20)
- `/week` week-to-date totals and top categories
- `/month [offset]` current month or offset month (`-1` previous)
- `/undo` shows most recent expense and sheet link for manual removal
- `/help` command and shortcut cheat sheet

## Categorization Rules

Category families include:
- Food and Drink
- Transport
- Shopping
- Bills and Utilities
- Medical
- Business Software
- Business Travel
- Business Meals
- Business Supplies
- Vendor Payment
- Cash
- Other (fallback)

Reference files:
- `setup/categorization-rules.md`
- category rule arrays inside workflows A and B.
