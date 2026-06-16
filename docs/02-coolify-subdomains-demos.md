# 02 — Coolify, Wildcard Subdomains & Demo Apps

**Goal:** any app — Laravel, Node, static site, or arbitrary Docker image — goes live on `https://<anything>.<DOMAIN>` in minutes, with basic-auth for client demos. Zero registrar visits per app.

**Why Coolify (recap):** open-source PaaS on your own box — Git-push deploys, automatic Let's Encrypt TLS, env management, logs, one dashboard, no per-app fees. **Why wildcard DNS:** one DNS record serves unlimited subdomains; new demo = new Coolify resource, nothing else.

---

## 1. DNS at the registrar (one-time)

| Type | Host | Value | TTL |
|---|---|---|---|
| A | `*` | `<SERVER_IP>` | 600 → raise to 3600 when stable |
| A | `@`-adjacent records | **untouched** | — |

> The wildcard covers `staging.`, `coolify.`, `demo-x.`, etc. Explicit records you may already have (root, `www`, mail) take precedence and stay pointed wherever they are — production remains untouched. Verify: `dig +short anything.<DOMAIN>` → `<SERVER_IP>`.

> 🔒 Tradeoff to know: any subdomain now resolves to your VPS, so a typo'd or guessed subdomain hits Traefik (which returns 404 for unconfigured hosts). That's normal and fine; just never assume "hidden subdomain" = private. Privacy comes from basic-auth or Tailscale, not obscurity.

## 2. Coolify instance domain + TLS

Coolify (installed in doc 01) → Settings → set instance URL `https://coolify.<DOMAIN>`. Let's Encrypt issues automatically (port 80 is open for the challenge). Daily access: prefer the Tailscale IP; the public hostname is convenience — if you want it fully private later, remove its DNS reliance and go tailnet-only.

## 3. GitHub connection (one-time)

Coolify → Sources → **GitHub App** → install on `<GIT_ORG>`, grant only the repos it should deploy. This enables private-repo pulls + push-to-deploy webhooks.

## 4. The four demo-app patterns

Create once per app: Coolify → Project (`demos` or per-client) → New Resource → Application.

| Stack | Build pack | Key settings |
|---|---|---|
| **Laravel** | Nixpacks (or repo Dockerfile — `templates/laravel.Dockerfile` in this repo) | Health `/up` · persistent volume on `storage/app` · post-deploy `php artisan migrate --force && php artisan storage:link && php artisan optimize` · attach a Coolify-managed MySQL per app |
| **Node** (Next/Express/etc.) | Nixpacks auto-detects | Set `PORT` env if the app doesn't read Coolify's; health = any 200 route |
| **Static** (HTML/Vite/Astro build) | Static build pack | Build cmd (`npm run build`) + publish dir (`dist`/`build`) |
| **Docker image** | "Docker Image" resource | Point at registry image:tag; map the container port; env as needed. For multi-service, use the **Docker Compose** build pack instead |

Each gets: Domain `https://<app>.<DOMAIN>` (wildcard makes it instant) → HTTPS on → deploy.

## 5. Basic-auth on demos (the client gate)

Coolify exposes Traefik middleware per app. Generate a credential, then attach:

```bash
# anywhere with apache2-utils / htpasswd:
htpasswd -nb client demo-password
# → client:$apr1$....   (escape $ as $$ if pasting into a label/UI that interpolates)
```

In the app's **Advanced/Proxy** settings add the BasicAuth middleware with that `user:hash`. Result: browser auth prompt before the demo loads. One credential per client; rotate after the demo cycle. Staging can stay open or gated the same way — your call per app.

> Per-app basic-auth is deliberately lightweight. Anything *internal* (dashboards) uses Tailscale instead — stronger model, no passwords to leak.

## 6. Resource hygiene (shared 12 GB box)

Set per-app **memory limits** in Coolify (demos: 256–512 MB; staging: 512 MB–1 GB) so one leaky demo can't starve the agents. Stop demos that aren't actively being shown — restart before the client call; cold start is seconds.

## 7. Validation

- [ ] `https://random123.<DOMAIN>` → Traefik 404 (wildcard live, nothing leaked).
- [ ] Staging app deployed per §9, green on `/up`.
- [ ] One demo of each stack you actually use deploys clean.
- [ ] Basic-auth prompt appears on a gated demo; wrong password rejected.
- [ ] Production/root DNS untouched.

## 8. Reuse notes

- Per-client pattern: a Coolify **Project per client**, apps inside it, one basic-auth credential per client, optionally `client-x.<DOMAIN>` naming or the client's own domain (Coolify handles any domain whose DNS points at the box).
- The demo-pattern table above is your internal "supported stacks" menu when selling.

## 9. Appendix — Laravel staging deployment (reference procedure)

The §4 Laravel pattern in concrete, first-app form. Never point staging at a production database.

1. **App resource:** Project → environment `staging` → New Resource → Application → private repo via the GitHub App (§3) → branch `main` → build pack **Nixpacks** (validate the pipeline first; switch to `templates/laravel.Dockerfile` once green) → domain `https://staging.<DOMAIN>` → health check `/up` (Laravel 12 default).
2. **Database:** New Resource → Database → **MySQL 8**; let Coolify generate name/user/password. Use the **internal hostname** Coolify shows for `DB_HOST` — apps reach the DB over the internal Docker network; never expose its port publicly.
3. **Environment** (app → Environment):

   ```env
   APP_ENV=staging
   APP_KEY=                  # local: php artisan key:generate --show — paste, never commit
   APP_DEBUG=false
   APP_URL=https://staging.<DOMAIN>
   DB_CONNECTION=mysql
   DB_HOST=                  # Coolify-internal hostname (step 2)
   DB_PORT=3306
   DB_DATABASE=              # ┐
   DB_USERNAME=              # ├ from the Coolify DB resource
   DB_PASSWORD=              # ┘
   SESSION_DRIVER=database
   CACHE_STORE=database
   QUEUE_CONNECTION=database
   FILESYSTEM_DISK=local
   ```

4. **Persistent storage:** volume mounted at `/var/www/html/storage/app` — uploads must survive redeploys.
5. **Deploy**, then post-deploy commands: `php artisan migrate --force && php artisan storage:link && php artisan optimize`.

### Troubleshooting

| Symptom | Likely cause → fix |
|---|---|
| 500 on every page | Missing/invalid `APP_KEY` → set a valid `base64:` key, redeploy |
| `Vite manifest not found` | Assets not built → ensure `npm run build` ran; check `public/build` exists |
| `SQLSTATE… connection refused` | Wrong `DB_HOST` → use the Coolify **internal** hostname, not localhost/IP |
| Uploads disappear after redeploy | No persistent volume → step 4, then rerun `storage:link` |
| 403 / wrong root | Web root must point at `public/` |
