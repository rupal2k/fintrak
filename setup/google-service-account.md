# Google API Setup — Get Your Service Account Key

This guide gets you a `google-credentials.json` file. The setup wizard uses this file to create and manage your Google Sheet and Drive folder automatically — you don't need to do anything in Google Sheets yourself.

**Time needed:** ~10 minutes

> **Stop at Step 5.** The setup wizard handles everything after that (creating the sheet, sharing it, etc.) automatically.

---

## Step 1: Create a Google Cloud Project

1. Go to https://console.cloud.google.com
2. Sign in with the **same Google account** that owns your Fintrak spreadsheet
3. Click the project dropdown (top-left, next to "Google Cloud" logo)
4. Click **"New Project"**
   - Project name: `Fintrak`
   - Organization: leave as-is
   - Click **"Create"**
5. Wait ~10 seconds, then select "Fintrak" from the project dropdown

---

## Step 2: Enable Google Sheets API

1. In the search bar at top, type: `Google Sheets API`
2. Click the result (shows a blue sheets icon)
3. Click **"Enable"**
4. Wait for it to activate (green checkmark appears)

---

## Step 3: Enable Google Drive API

1. In the search bar, type: `Google Drive API`
2. Click the result
3. Click **"Enable"**

---

## Step 4: Create a Service Account

1. In the left sidebar: **APIs & Services → Credentials**
2. Click **"+ Create Credentials"** → **"Service Account"**
3. Fill in:
   - **Service account name:** `fintrak-automation`
   - **Service account ID:** auto-fills (leave it)
   - **Description:** `n8n automation for Fintrak`
4. Click **"Create and Continue"**
5. Skip the optional role/user steps — click **"Done"**

---

## Step 5: Download the JSON Key

1. In the Credentials page, click on `fintrak-automation` in the service accounts list
2. Go to the **"Keys"** tab
3. Click **"Add Key"** → **"Create new key"** → **JSON** → **"Create"**
4. A `.json` file downloads automatically — this is your `google-credentials.json`
5. **Save it somewhere you can easily find it** (Desktop is fine)

> **Keep this file private.** It gives access to your Google account. Never share it or upload it anywhere.

**You're done with Google setup.** Go back to the README and continue the setup wizard — it will ask you for the path to this file and handle everything else automatically.

---

## What the setup wizard does automatically (you don't need to do this)

For reference, the wizard will:
- Create the "Fintrak Expenses" Google Sheet with 4 tabs and all formulas
- Create the "Fintrak/Receipts" folder in your Google Drive
- Share both with your personal Google email so you can access them
- Connect everything to the automation engine

---

## Troubleshooting

**"The caller does not have permission"** error in n8n:
- The sheet or folder is not shared with the service account email
- Re-check Steps 6 and 7

**"Invalid grant"** error:
- The private key was copied incorrectly — it must include both header and footer lines
- Try copying the `private_key` value from the JSON file again, making sure there are no extra spaces

**Credentials show red X in n8n:**
- APIs not enabled — re-check Steps 2 and 3
- Wrong project selected in Google Cloud Console
