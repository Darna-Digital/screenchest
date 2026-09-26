# www

The ScreenChest marketing site, a TanStack Start app on Cloudflare Workers.
Its structure and styling mirror reviewer.sh.

```bash
pnpm dev         # the site on :41842
pnpm build       # dist/client (assets) and dist/server (the Worker)
pnpm run deploy  # vite build, then wrangler deploy
```

## Screenshots

Captures are taken on a Retina display and shown at half their pixel size, so
a small crop stays sharp instead of being stretched across the card. Each
entry in `SCREENSHOTS` in `src/routes/index.tsx` has a `capture`:

- `pending` shows a placeholder with the expected name.
- `single` is one capture for both appearances: `public/screenshots/<name>.avif`.
- `themed` is a light and a dark capture:
  `public/screenshots/<name>-light.avif` and `<name>-dark.avif`.

Set `width` and `height` to the image's pixel size. Encode with
`avifenc -q 72 -s 4 <name>.png <name>.avif`, scaling anything wider than
2880px down first.

## Deploying

`wrangler.jsonc` serves the Worker `screenchest-www` on `screenchest.com` as a
custom domain. The domain must be an active zone on the same Cloudflare account
as `CLOUDFLARE_ACCOUNT_ID`, and any existing A/AAAA/CNAME record on the apex
has to go first, or the deploy fails. `CLOUDFLARE_API_TOKEN` needs Workers
Scripts edit on the account and Workers Routes and DNS edit on the zone.

`.github/workflows/deploy-www.yml` checks and deploys on every push to `main`
that touches `www/`, with `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from
the repository's `production` environment. Pull requests touching `www/` run
`check-www.yml` alone.

`DOWNLOAD_URL` in `src/lib/links.ts` is still a placeholder.
