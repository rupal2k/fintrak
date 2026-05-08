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
| Send `/summary` | Replies with this month's totals |
| Send `/report` | Full breakdown by category |
| Do nothing at 9 PM | Bot sends you today's spending summary |

---

## Before you start — collect these 5 things

The setup wizard will ask for these one by one. Get them ready first.
**Total time: ~25 minutes** (most of it is waiting for Google pages to load).

---

### Thing 1 — Docker Desktop (~5 min to install)

Docker is the engine that runs Fintrak on your computer.

1. Go to **[docker.com/get-started](https://www.docker.com/get-docker)**
2. Download **Docker Desktop** for your operating system
3. Install it and open it
4. You should see a whale icon in your taskbar/menu bar — that means it's running

> **Windows users:** Docker Desktop may ask you to install WSL 2 (Windows Subsystem for Linux). Follow the prompts — it's safe and takes about 3 minutes.

---

### Thing 2 — Telegram bot token (~3 min)

This is your bot's password. You get it by creating a bot in Telegram.

1. Open Telegram on your phone or computer
2. Search for **@BotFather** and open the chat (look for the blue verified checkmark ✓)
3. Send the message: `/newbot`
4. When asked for a name, send: `Fintrak`
5. When asked for a username, send: `fintrak_yourname_bot` (must end in `_bot`)
6. BotFather will reply with your **bot token** — it looks like: `7234567890:AAFxxxxxxxxxxxxxxx`
7. **Copy and save this token somewhere** — you'll paste it during setup

---

### Thing 3 — Your Telegram chat ID (~1 min)

This is your personal Telegram ID number. Fintrak uses it to make sure only you can use the bot.

1. In Telegram, search for **@userinfobot** and open the chat
2. Send it any message (like `hello`)
3. It replies with `Id: 123456789`
4. **Copy that number** — you'll paste it during setup

---

### Thing 4 — Google service account key file (~10 min)

This is a file that lets Fintrak read and write your Google Sheet on your behalf.
It's more technical but the guide below walks through every click.

**Follow the guide here:** [setup/google-service-account.md](setup/google-service-account.md)

At the end of that guide you'll have a file called `google-credentials.json` on your computer.
**Remember where you saved it** — you'll give the setup wizard its location.

---

### Thing 5 — OCR.Space API key (~2 min, free)

This service reads text from your receipt photos. Free plan allows 25,000 receipts/month.

1. Go to **[ocr.space/ocrapi](https://ocr.space/ocrapi)**
2. Click **"Register for free API key"**
3. Enter your email and submit
4. Check your email — you'll receive a key that starts with `K8`
5. **Copy that key** — you'll paste it during setup

---

## Download Fintrak

### Option A — Download as ZIP (no technical knowledge needed)

1. On this GitHub page, click the green **`< > Code`** button (top right of the file list)
2. Click **"Download ZIP"**
3. Find the downloaded file (usually in your Downloads folder)
4. Right-click it → **"Extract All"** (Windows) or double-click (Mac)
5. Move the extracted `fintrak-main` folder somewhere easy to find, like your Desktop

### Option B — Using git (if you know what that is)

```bash
git clone https://github.com/rupal2k/fintrak.git
cd fintrak
```

---

## Run the setup wizard

Open the `fintrak` folder, then:

### Windows

**Option 1 — Double-click** `setup.bat` in the folder

**Option 2 — PowerShell:**
1. Right-click inside the folder → **"Open in Terminal"** (or search "PowerShell" in Start menu)
2. Type this and press Enter:
   ```
   .\setup.ps1
   ```

### Mac

1. Open **Terminal** (press `Cmd + Space`, type "Terminal", press Enter)
2. Type `cd ` (with a space after), then drag the fintrak folder into the Terminal window, press Enter
3. Run:
   ```bash
   chmod +x setup.sh && ./setup.sh
   ```

### Linux

```bash
chmod +x setup.sh && ./setup.sh
```

---

## What the wizard does

Once you run it, the wizard will:

1. Ask you 6 questions (your credentials from the steps above)
2. Start the Fintrak engine in the background
3. Automatically create your **"Fintrak Expenses"** Google Sheet with all tabs and formulas
4. Automatically create your **"Fintrak/Receipts"** folder in Google Drive
5. Share both with your personal Google account
6. Set up all 4 automation workflows
7. Send a test message to your Telegram bot to confirm everything works

**Total time: about 2–3 minutes after you answer the questions.**

At the end you'll see:
```
🎉 Fintrak is live!
   Google Sheet  : https://docs.google.com/spreadsheets/d/...
   Telegram bot  : Send a receipt photo to get started
```

---

## Using Fintrak every day

### Log an expense from a receipt photo

1. Open Telegram
2. Find your bot (the username you created with BotFather)
3. Take a photo of any receipt and send it
4. Within 10 seconds the bot replies:
   ```
   ✅ Saved!
   🏪 Merchant: Starbucks
   💰 Amount: ₹250
   📂 Category: Food & Drink
   ```
5. The expense is now in your Google Sheet

### Log an expense by typing

Send your bot a message in this format:

```
amount merchant notes
```

**Examples:**

| Message you send | What gets logged |
|-----------------|-----------------|
| `250 starbucks coffee` | ₹250 · Starbucks · Food & Drink · Personal |
| `b:500 vendor payment abc ltd` | ₹500 · Vendor Payment · Business |
| `1200 electricity bill` | ₹1200 · Bills & Utilities · Personal |
| `cash 300 auto rickshaw` | ₹300 · Transport · Cash payment |

> **Tip:** Start with `b:` to mark an expense as Business. Everything else is Personal by default.

### Check your spending

Send these commands to your bot:

| Command | What you get |
|---------|-------------|
| `/summary` | This month's total — Personal, Business, Grand total |
| `/report` | Breakdown by category (Food, Transport, Bills, etc.) |
| `/search coffee` | All expenses matching "coffee" |
| `/help` | Shows all available commands |

### Daily summary

Every evening at **9:00 PM**, your bot automatically sends:
```
📊 Today: Personal ₹450 | Business ₹0 | Total ₹450
```

---

## Troubleshooting

### "Docker is not running"
Open Docker Desktop from your Start menu / Applications folder. Wait for the whale icon to appear in your taskbar, then re-run the setup wizard.

### "File not found" when entering Google credentials path
The setup wizard needs the exact path to your `google-credentials.json` file. Tips:
- **Windows:** Right-click the file → "Copy as path" → paste that
- **Mac/Linux:** Drag the file into the terminal window — it will type the path for you

### Setup wizard shows an error about Google APIs
You need to enable two APIs in Google Cloud Console before setup can work:
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Make sure the "Fintrak" project is selected (top-left dropdown)
3. Search for "Google Sheets API" → click Enable
4. Search for "Google Drive API" → click Enable
5. Re-run the setup wizard

### "n8n did not become healthy"
Docker may still be starting up. Wait 30 seconds and re-run the setup wizard — it will skip steps that already completed.

### The bot doesn't respond to my messages
1. Make sure you started a conversation with your bot first (send it `/start`)
2. Check that your Telegram chat ID is correct — get it again from @userinfobot
3. Re-run the setup wizard — it will detect which steps are already done and skip them

### I accidentally closed the terminal mid-setup
No problem. Re-run the setup wizard — it detects what was already set up and continues from where it left off.

---

## Frequently asked questions

**Is my financial data safe?**
Yes. Everything is stored in your own Google account — Fintrak never sends your data to anyone. The only external services are Telegram (to receive messages), OCR.Space (to read receipt text), and Google (to store data).

**What happens to my data if I stop using Fintrak?**
Your Google Sheet and Drive photos stay in your Google account forever. Just stop running Docker and nothing else changes.

**Can I edit the Google Sheet manually?**
Yes. The sheet is a normal Google Sheet — you can edit, delete, or add rows directly.

**Can someone else use my bot?**
No. The setup gives your bot your personal Telegram ID, so it only responds to messages from you.

**What if I get a new phone?**
Nothing changes — the bot runs on your computer, not your phone. Just open Telegram on your new phone and find your bot.

**Can I run this on my phone instead of a computer?**
Fintrak needs to run on a computer (or a home server / VPS). Your phone just uses Telegram to send receipts.

**Does this work when my computer is off?**
No. The bot only works when your computer is on and Docker is running. If you want it to run 24/7, you can move it to a cheap cloud server later (optional, not required for personal use).

---

## Cost breakdown

| Service | Cost |
|---------|------|
| Docker (self-hosted on your computer) | Free |
| Telegram bot | Free |
| Google Sheets | Free (15 GB storage) |
| Google Drive | Free (15 GB storage) |
| OCR.Space (receipt reading) | Free (25,000 receipts/month) |
| **Total** | **₹0 / month** |

---

## Need help?

If you're stuck, [open an issue](https://github.com/rupal2k/fintrak/issues) and describe what step you're on and what error you see. Include a screenshot if possible.
