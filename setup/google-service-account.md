# Google API Setup — Service Account

This guide walks you through creating a service account that lets n8n read/write your Google Sheets and Google Drive without OAuth pop-ups.

**Time needed:** ~10 minutes

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
4. A `.json` file downloads automatically
5. Rename it to `google-credentials.json`
6. Move it to: `C:\Rupalprojects\Fintrak\setup\google-credentials.json`

> **IMPORTANT:** This file contains your private key. It is in `.gitignore` and will never be committed. Never share it.

Open the file and find the `client_email` field. It looks like:
```
fintrak-automation@fintrak-123456.iam.gserviceaccount.com
```
**Copy this email address** — you'll need it in Steps 6 and 7.

---

## Step 6: Share Google Sheet with Service Account

1. Open your **Fintrak Expenses** spreadsheet
2. Click **"Share"** (top-right green button)
3. Paste the `client_email` from Step 5
4. Set permission to **"Editor"**
5. **Uncheck "Notify people"**
6. Click **"Share"**

---

## Step 7: Share Google Drive Folder with Service Account

1. Go to https://drive.google.com
2. Open your **Fintrak/Receipts** folder
3. Right-click the folder → **"Share"**
4. Paste the same `client_email`
5. Set permission to **"Editor"**
6. Click **"Share"**

---

## Step 8: Add Credentials to n8n

Open n8n at http://localhost:5678.

### For Google Sheets:
1. Avatar (bottom-left) → **Credentials** → **"Add Credential"**
2. Search for **"Google Sheets"** → select **"Google Sheets API"**
3. Name: `Fintrak Google Sheets`
4. Authentication: **"Service Account"**
5. **Service Account Email:** paste the `client_email` from Step 5
6. **Private Key:** open `google-credentials.json`, find `"private_key"`, copy the entire value including `-----BEGIN PRIVATE KEY-----` through `-----END PRIVATE KEY-----\n`
7. Click **"Save"** — should show green checkmark

### For Google Drive:
1. **"Add Credential"** → search **"Google Drive"** → **"Google Drive API"**
2. Name: `Fintrak Google Drive`
3. Authentication: **"Service Account"**
4. Same **Service Account Email** and **Private Key** as above
5. Click **"Save"**

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
