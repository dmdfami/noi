#!/usr/bin/env bash
# Deploy the Nói landing page (site/) to Cloudflare Pages.
#
# One-time: create the Pages project + point a subdomain of d92.uk at it.
# Requires a Cloudflare API token with Pages edit permission.
#
#   export CLOUDFLARE_API_TOKEN=...      # Pages:Edit
#   export CLOUDFLARE_ACCOUNT_ID=...     # your CF account id
#   PROJECT=noi ./scripts/deploy-landing.sh
#
# Custom domain (noi.d92.uk): after the first deploy, add it in the
# Cloudflare dashboard → Pages → <project> → Custom domains → "noi.d92.uk"
# (CF auto-creates the CNAME because d92.uk is on the same account), or:
#   npx wrangler pages domain add noi.d92.uk --project-name "$PROJECT"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${PROJECT:-noi}"
SITE="$ROOT/site"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "error: set CLOUDFLARE_API_TOKEN (Pages:Edit) and CLOUDFLARE_ACCOUNT_ID" >&2
  echo "get a token: https://dash.cloudflare.com/profile/api-tokens" >&2
  exit 1
fi

echo "deploying $SITE → Cloudflare Pages project '$PROJECT'…" >&2
npx --yes wrangler@4 pages deploy "$SITE" \
  --project-name "$PROJECT" \
  --commit-dirty=true

echo "done. Add custom domain once: noi.d92.uk (Pages → $PROJECT → Custom domains)." >&2
