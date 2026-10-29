#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! vercel whoami &>/dev/null; then
  echo "Vercel session not found on this fresh OS install. Logging in..."
  vercel login
fi

echo "Deploying Softify Fleet Controller & Admin Dashboard to Vercel Production..."
vercel deploy --prod --yes \
  -e ADMIN_KEY=2010 \
  -e GITHUB_GIST_ID=a8e25d128307d38d875a138da38a7ddd \
  -e GITHUB_TOKEN="$(gh auth token)"

echo "✅ Admin Dashboard deployed to https://server-eight-gamma-81.vercel.app"
