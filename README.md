# Fintrak — Free Personal & Business Expense Tracker

**Take a photo of any receipt → send it to your Telegram bot → it's automatically saved to your Google Sheet.**

No monthly fees. No app to buy. Works on any phone. Your data stays in your own Google account.

<img width="2752" height="1536" alt="image" src="https://github.com/user-attachments/assets/3381fd84-aa8b-4ad4-95c5-d99ac2004bd2" />

---

## What does it do?

| You do this... | Fintrak does this automatically |
|---------------|-------------------------------|
| Send a receipt photo to your bot | Reads the amount, merchant, date → saves to Google Sheet |
| Type `250 starbucks coffee` | Logs ₹250 under Food & Drink → Personal |
| Type `b:500 vendor payment` | Logs ₹500 as Business expense |
| Type `y:300 auto` | Logs ₹300 under yesterday's date |
| Type `5k swgy dinner` | Logs ₹5,000 at Swiggy — `k` means × 1,000 |
| Send `/summary` | This month's totals + % change vs last month |
| Send `/today` | Itemized list of everything you spent today |
| Send `/last 10` | Your last 10 expenses |
| Send `/week` | This week's spending by category |
| Send `/report` | Full breakdown by category |
| Send `/undo` | Shows your last expense + link to edit it |
| Do nothing at 9 PM | Bot sends today's summary + vs-yesterday comparison |

---

## Before you start — collect these 4 things

The setup wizard will ask for these one by one. Get them ready first.
**Total time: about 20 minutes** (most of it is waiting for Google pages to load).

---

### Thing 1 — Telegram bot token (~3 min)

This is your bot's password. You get it by creating a bot in Telegram.

1. Open Telegram on your phone or computer
2. Search for **@BotFather** and open the chat (look for the blue verified checkmark ✓)
3. Send the message: `/newbot`
4. When asked for a name, send: `Fintrak`
5. When asked for a username, send: `fintrak_yourname_bot` (must end in `_bot`)
6. BotFather will reply with your **bot token** — it looks like: `7234567890:AAFxxxxxxxxxxxxxxx`
7. **Copy and save this token** — you'll paste it during setup

---

### Thing 2 — Your Telegram chat ID (~1 min)

This is your personal Telegram ID number. Fintrak uses it to make sure only you can use the bot.

1. In Telegram, search for **@userinfobot** and open the chat
2. Send it any message (like `hello`)
3. It replies with `Id: 123456789`
4. **Copy that number** — you'll paste it during setup

---

### Thing 3 — Google service account key file (~10 min)

This is a file that lets Fintrak read and write your Google Sheet on your behalf.
It's the most technical step but the guide below walks through every click.

**Follow the guide here:** [setup/google-service-account.md](setup/google-service-account.md)

At the end you'll have a file called `google-credentials.json` on your device.
**Remember where you saved it** — the setup wizard will ask for it.

---

### Thing 4 — OCR.Space API key (~2 min, free)

This service reads text from your receipt photos. Free plan allows 25,000 receipts/month.

1. Go to **[ocr.space/ocrapi](https://ocr.space/ocrapi)**
2. Click **"Register for free API key"**
3. Enter your email and submit
4. Check your email — you'll receive a key that starts with `K8`
5. **Copy that key** — you'll paste it during setup

---

## Download and install Fintrak

Choose the option that matches your device:

---

### Windows

**Step 1 — Download**
1. On this GitHub page, click the green **`< > Code`** button (top right of the file list)
2. Click **"Download ZIP"**
3. Find the downloaded file in your Downloads folder
4. Right-click it → **"Extract All"**
5. Move the `fintrak-main` folder somewhere easy to find, like your Desktop

**Step 2 — Install Docker Desktop (~5 min)**

Docker is the engine that runs Fintrak on your computer.

1. Go to **[docker.com/get-docker](https://www.docker.com/get-docker)**
2. Download **Docker Desktop for Windows**
3. Install it and open it — look for the whale icon in your taskbar

> **Note:** Docker may ask you to install WSL 2. Follow the prompts — it's safe and takes about 3 minutes.

**Step 3 — Run the setup wizard**

Double-click **`setup.bat`** inside the fintrak folder — that's it.

Alternatively, right-click inside the folder → **"Open in Terminal"** and type:
```
.\setup.ps1
```

---

### Mac

**Step 1 — Download**
1. Click the green **`< > Code`** button on this page → **"Download ZIP"**
2. Double-click the ZIP to extract it
3. Move the `fintrak-main` folder to your Desktop

**Step 2 — Install Docker Desktop (~5 min)**

1. Go to **[docker.com/get-docker](https://www.docker.com/get-docker)**
2. Download **Docker Desktop for Mac**
3. Install it and open it — look for the whale icon in your menu bar

**Step 3 — Run the setup wizard**

1. Open **Terminal** (press `Cmd + Space`, type "Terminal", press Enter)
2. Type `cd ` (with a space), then drag the fintrak folder into the Terminal window, press Enter
3. Run:
   ```bash
   chmod +x setup.sh && ./setup.sh
   ```

---

### Android (no computer needed)

> Your Android phone becomes the server. Fintrak runs inside Termux — a free terminal app. No Docker required. The bot works as long as Termux is running on your phone.

**Step 1 — Install Termux**

Install **Termux** from [F-Droid](https://f-droid.org/packages/com.termux/) — do **not** use the Play Store version (it is outdated). Open Termux after installing.

**Step 2 — Copy your Google credentials file to your phone**

Email the `google-credentials.json` file to yourself → open it in Gmail on your phone → tap the attachment → **Save to Downloads**.

**Step 3 — Download and run Fintrak**

In Termux, paste these two commands one at a time and press Enter after each:

```bash
pkg update && pkg install -y git
git clone https://github.com/rupal2k/fintrak.git ~/fintrak
```

Then start the setup wizard:
```bash
cd ~/fintrak && chmod +x setup-android.sh && ./setup-android.sh
```

The wizard installs everything, walks you through each credential, creates your Google Sheet, and asks if you want Fintrak to start automatically when your phone reboots.

---

### Linux

```bash
git clone https://github.com/rupal2k/fintrak.git && cd fintrak
chmod +x setup.sh && ./setup.sh
```

---

## What the setup wizard does

Once you run it, the wizard will:

1. Ask for your 4 credentials (from the steps above)
2. Start the Fintrak engine in the background
3. Automatically create your **"Fintrak Expenses"** Google Sheet with all tabs and formulas
4. Automatically create your **"Fintrak/Receipts"** folder in Google Drive
5. Share both with your personal Google account
6. Set up all 4 automation workflows
7. Send a test message to your Telegram bot to confirm everything works

**Total time: about 2–3 minutes after you answer the questions.**

---

## Using Fintrak every day

### Log an expense from a receipt photo

1. Open Telegram and find your bot
2. Take a photo of any receipt and send it
3. Within 10 seconds the bot replies:
   ```
   ✅ Saved!
   🏪 Starbucks — ₹250
   📂 Food & Drink · Personal · UPI
   ```
4. The expense is now in your Google Sheet

### Log an expense by typing

Send your bot a message in this format: `amount merchant notes`

| Message you send | What gets logged |
|-----------------|-----------------|
| `250 starbucks coffee` | ₹250 · Starbucks · Food & Drink · Personal |
| `b:500 vendor payment abc ltd` | ₹500 · Vendor Payment · Business |
| `1200 electricity bill` | ₹1200 · Bills & Utilities · Personal |
| `cash 300 auto rickshaw` | ₹300 · Transport · Cash payment |
| `y:450 sbux latte` | ₹450 · Starbucks · **yesterday's date** |
| `5k amzn headphones` | ₹5,000 · Amazon · Shopping |

**Shortcuts:**

| Shortcut | What it does |
|---------|-------------|
| `b:` at the start | Marks the expense as Business |
| `y:` at the start | Logs to yesterday instead of today |
| `5k` | Means ₹5,000 — `k` multiplies by 1,000 |
| `₹`, `$`, `€` | Currency symbols are stripped automatically |
| `sbux` | Starbucks · `swgy` = Swiggy · `zmto` = Zomato |
| `amzn` | Amazon · `mcds` = McDonalds · `uber` = Uber |

### Check your spending

| Command | What you get |
|---------|-------------|
| `/summary` | This month's totals (Personal + Business) with % change vs last month |
| `/today` | Every expense logged today, itemized |
| `/last` | Your last 5 expenses — use `/last 10` for more |
| `/week` | This week's total, broken down by top categories |
| `/month` | This month in detail — use `/month -1` for last month |
| `/report` | Full breakdown by category for this month |
| `/search coffee` | All expenses matching "coffee" |
| `/undo` | Shows your most recent expense + a link to edit it in Google Sheets |
| `/help` | Shows all available commands and shortcuts |

### Daily summary

Every evening at **9:00 PM**, your bot automatically sends:
```
📊 Daily Summary — 2026-05-09

3 expense(s)
👤 Personal: ₹650
💼 Business: ₹0
💰 Total: ₹650
vs yesterday ₹450 (↑44%)

Today:
• Starbucks ₹250 (Food & Drink)
• Auto ₹100 (Transport)
• Electricity ₹300 (Bills & Utilities)

May total: ₹4,200
```

---

## Troubleshooting

### "Docker is not running"
Open Docker Desktop from your Start menu or Applications folder. Wait for the whale icon to appear in your taskbar, then re-run the setup wizard.

### "File not found" when entering Google credentials path
- **Windows:** Right-click the file → "Copy as path" → paste that into the wizard
- **Mac:** Drag the file into the Terminal window — it will type the path for you
- **Android:** The wizard shows a numbered list of JSON files in your Downloads — just pick a number

### Setup wizard shows an error about Google APIs
You need to enable two APIs in Google Cloud Console:
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Make sure the "Fintrak" project is selected (top-left dropdown)
3. Search for "Google Sheets API" → click Enable
4. Search for "Google Drive API" → click Enable
5. Re-run the setup wizard

### "n8n did not become healthy"
Wait 30 seconds and re-run the setup wizard — it will skip steps that already completed.

### The bot doesn't respond to my messages
1. Make sure you started a conversation with your bot first (send it `/start`)
2. Check that your Telegram chat ID is correct — get it again from @userinfobot
3. Re-run the setup wizard — it will detect which steps are already done and skip them

### I accidentally closed the terminal mid-setup
No problem. Re-run the setup wizard — it detects what was already set up and continues from where it left off.

---

## Frequently asked questions

**Is my financial data safe?**
Yes. Everything is stored in your own Google account — Fintrak never sends your data to anyone else. The only external services used are Telegram (to receive messages), OCR.Space (to read receipt text), and Google (to store data).

**What happens to my data if I stop using Fintrak?**
Your Google Sheet and Drive photos stay in your Google account forever. Just stop running Fintrak — your data is untouched.

**Can I edit the Google Sheet manually?**
Yes. It's a normal Google Sheet — you can edit, delete, or add rows directly at any time.

**Can someone else use my bot?**
No. Fintrak uses your personal Telegram ID, so the bot only responds to messages from you.

**What if I get a new phone?**
If you run Fintrak on a **computer** — nothing changes. Open Telegram on your new phone and your bot still works.

If you run Fintrak on **Android (Termux)** — re-run `./setup-android.sh` on your new phone. Your Google Sheet data is safe in Google Drive.

**Does this work when my device is off?**
No — Fintrak only works while the device running it is on. For computers: Docker must be running. For Android: Termux must be open. If you enable auto-start during setup, it starts automatically on reboot.

---

## Cost breakdown

| Service | Cost |
|---------|------|
| Fintrak (self-hosted) | Free |
| Telegram bot | Free |
| Google Sheets | Free (15 GB storage) |
| Google Drive | Free (15 GB storage) |
| OCR.Space (receipt reading) | Free (25,000 receipts/month) |
| **Total** | **₹0 / month** |

---

## Need help?

If you're stuck, [open an issue](https://github.com/rupal2k/fintrak/issues) and describe what step you're on and what error you see. Include a screenshot if possible.
