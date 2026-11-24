# Softify Free Cloudflare Backend: Setup & Deployment Guide

This guide details the exact click-by-click steps to set up the free Cloudflare backend for Softify. 

> [!IMPORTANT]
> **Total Cost**: Exactly **$0.00**. Cloudflare's permanent free tier requires **no credit card** and charges nothing as long as you stay on the Free plan.

---

## 1. Cloudflare Dashboard: Setup (Click-by-Click)

### Step 1: Create a Free Cloudflare Account
1. Open [https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up) in your browser.
2. Enter your email and a secure password.
3. Complete the email verification. **Do not** add a payment method or select any paid plan.

### Step 2: Retrieve Your Cloudflare Account ID
1. In the Cloudflare Dashboard, click **Workers & Pages** in the left sidebar navigation.
2. In the right-hand panel, find **Account ID**.
3. Click the copy icon to copy your 32-character hexadecimal Account ID.
   *(Save this as `CLOUDFLARE_ACCOUNT_ID`).*

### Step 3: Create a Scoped API Token
1. In the top right corner of the dashboard, click your profile icon and select **My Profile**.
2. Click **API Tokens** in the left navigation.
3. Click **Create Token**.
4. Select the **Edit Cloudflare Workers** template, or click **Create Custom Token**:
   - **Token Name**: `Softify-Deploy-Token`
   - **Permissions**:
     - `Account` | `Workers Scripts` | `Edit`
     - `Account` | `Workers KV Storage` | `Edit`
     - `Account` | `D1` | `Edit`
     - `Account` | `Workers R2 Storage` | `Edit`
   - **Account Resources**: `Include` -> `All accounts` (or select your specific account).
   - **TTL / Expiry**: Set to `None` (or your preferred duration).
5. Click **Continue to summary**, then **Create Token**.
6. Copy the generated API Token.
   *(Save this as `CLOUDFLARE_API_TOKEN`).*

### Step 4: Create Cloudflare D1 Database
1. Navigate back to **Workers & Pages** > **D1 SQL Database**.
2. Click **Create database**.
3. Choose **Dashboard** creation:
   - **Database Name**: `softify-db`
4. Click **Create**.
5. Note the **Database ID** displayed on the database overview page (a UUID like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
   *(Save this as `CLOUDFLARE_D1_DATABASE_ID`).*

### Step 5: Create Cloudflare KV Namespace
1. In the sidebar under **Workers & Pages**, click **KV**.
2. Click **Create a namespace**.
3. Enter **Namespace Name**: `softify-kv`.
4. Click **Add**.
5. Copy the 32-character **Namespace ID**.
   *(Save this as `CLOUDFLARE_KV_NAMESPACE_ID`).*

### Step 6: Create Cloudflare R2 Bucket (Optional Backup Store)
1. In the sidebar under **Workers & Pages**, click **R2 Object Storage**.
2. Click **Create bucket**.
3. Enter **Bucket Name**: `softify-backups`.
4. Leave location hint as `Automatic` and click **Create bucket**.

---

## 2. GitHub Repository Secrets & Variables

In your GitHub repository (`Sarthak-Cyb3r/softify`):
1. Navigate to **Settings** > **Secrets and variables** > **Actions**.
2. Under **Repository secrets**, click **New repository secret** and add:
   - **`CLOUDFLARE_API_TOKEN`**: The API token generated in Step 3.
   - **`CLOUDFLARE_ACCOUNT_ID`**: The Account ID from Step 2.
3. Under **Repository variables**, click **New repository variable** and add:
   - **`CLOUDFLARE_D1_DATABASE_ID`**: The D1 database UUID from Step 4.
   - **`CLOUDFLARE_KV_NAMESPACE_ID`**: The KV namespace ID from Step 5.

> [!NOTE]
> The GitHub Actions deployment workflows are designed to **skip gracefully** with a clean informational notice if `CLOUDFLARE_API_TOKEN` is not present, ensuring PR and client CI builds never fail due to missing backend secrets.

---

## 3. Local Development & Testing (Wrangler / Miniflare)

To run the backend locally on your Fedora PC without affecting Cloudflare production quotas:
```bash
cd server
npm install
# Run local migrations against Miniflare local SQLite
npx wrangler d1 migrations apply softify-db --local
# Start local development server with Miniflare (0ms cold start)
npm run dev
```

---

## 4. Production Rollback Procedure

If a deployed Worker version exhibits an issue in production, Cloudflare supports zero-downtime instant rollbacks:
```bash
cd server
# 1. List recent deployments with IDs and timestamps
npx wrangler deployments list

# 2. Rollback immediately to a specific deployment ID
npx wrangler rollback <deployment-id>
```
Rolling back takes less than 2 seconds globally across Cloudflare's edge network.

---

## 5. D1 Database Time Travel & Restore Procedure

Cloudflare D1 provides built-in point-in-time recovery on the Free tier ("Time Travel") up to 7 days:
```bash
# 1. Inspect recent bookmark snapshots
npx wrangler d1 time-travel info softify-db

# 2. Restore the database to an exact bookmark timestamp
npx wrangler d1 time-travel restore softify-db --bookmark <bookmark-id>
```

---

## 6. Verification Checklist for Maintainer

- [ ] Free Cloudflare account created (no payment method attached).
- [ ] Account ID copied.
- [ ] Scoped API token created (`Workers`, `D1`, `KV`, `R2`).
- [ ] D1 database `softify-db` created.
- [ ] KV namespace `softify-kv` created.
- [ ] R2 bucket `softify-backups` created.
- [ ] GitHub Actions Secret `CLOUDFLARE_API_TOKEN` added.
- [ ] GitHub Actions Secret `CLOUDFLARE_ACCOUNT_ID` added.
- [ ] GitHub Actions Variable `CLOUDFLARE_D1_DATABASE_ID` added.
- [ ] GitHub Actions Variable `CLOUDFLARE_KV_NAMESPACE_ID` added.
