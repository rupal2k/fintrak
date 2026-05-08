# Categorization Rules Reference

Rules are applied in order inside n8n Code nodes. **First match wins.**

## Current Rules

| Priority | Category | Type | Trigger Keywords |
|----------|----------|------|-----------------|
| 1 | Food & Drink | Personal | zomato, swiggy, starbucks, cafe, restaurant, biryani, pizza, food, eat, dominos, mcdonald, kfc, burger, dine |
| 2 | Transport | Personal | uber, ola, rapido, petrol, fuel, toll, parking, auto, cab, rickshaw, metro, bus fare, train fare |
| 3 | Shopping | Personal | amazon, flipkart, myntra, mall, store, shop, meesho, snapdeal, ajio, retail |
| 4 | Bills & Utilities | Personal | electricity, water, broadband, jio, airtel, bsnl, recharge, bill, internet, wifi, gas cylinder, piped gas |
| 5 | Medical | Personal | pharmacy, hospital, doctor, clinic, medicine, apollo, medplus, 1mg, netmeds, health, dental, lab test |
| 6 | Business - Software | Business | aws, google cloud, notion, slack, zoom, adobe, subscription, saas, github, figma, canva, digitalocean |
| 7 | Business - Travel | Business | flight, hotel, train ticket, business travel, airport, business cab |
| 8 | Business - Meals | Business | client lunch, vendor meeting, team lunch, business meal, office lunch, client dinner |
| 9 | Business - Supplies | Business | office supplies, stationery, equipment, printer, laptop, monitor |
| 10 | Vendor Payment | Business | vendor, supplier, contractor, invoice payment, advance payment |
| 11 | Cash | Personal | atm, cash withdrawal, cash advance |
| 12 | Other | Personal | catch-all (no match above) |

## Business Override

Any message starting with `b:` forces **Type = Business** regardless of category.

```
b:250 lunch            → Food & Drink, Business
b:500 vendor xyz       → Vendor Payment, Business
b:1200 hotel stay      → Business - Travel, Business
```

## How to Add or Edit a Category

1. Open n8n at http://localhost:5678
2. Open Workflow A (Receipt Photo Processor)
3. Click the **Categorize** Code node
4. Edit the `rules` array — add a new object:
   ```js
   { category: 'Rent', type: 'Personal', keywords: ['rent', 'landlord', 'housing'] }
   ```
5. Click Save. Change is live immediately.
6. Repeat in **Workflow B** (Text Entry) Categorize node

## Keyword Matching Logic

- Matching is **case-insensitive**
- Checks both the **raw OCR text** and the **merchant name**
- Also checks the **user's caption** or typed note
- `b:` prefix in user note forces Business type on top of category result

## Tips for Better Categorization

- For receipts from **local shops** (no brand name): add the shop name as a keyword
- For **UPI payments** to vendors: type `b:amount vendor name` for instant business tagging
- For **recurring bills**: the merchant name on the receipt usually contains "bill", "invoice", or the utility company name — already covered
