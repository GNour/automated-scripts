# 03 — Remote Development Environment

**Goal:** open VS Code on any laptop and be *on the VPS*: full Laravel/Node toolchain, your repos, terminals — identical environment everywhere, and the same workspace Claude Code and Multica operate in.

**Why Remote-SSH over code-server:** zero extra exposed services (rides the hardened SSH you already have), native VS Code UX, extensions run server-side. code-server would add a public web IDE to defend for no gain.

---

## 1. Local SSH config (your laptop)

```sshconfig
# ~/.ssh/config
Host vps-dev
    HostName <SERVER_IP>          # or the Tailscale name, e.g. vps-1
    User <DEV_USER>
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 30
```

VS Code → install **Remote - SSH** extension → `Connect to Host… → vps-dev`. First connect installs the VS Code server under `<DEV_USER>` automatically.

> Tip: using the Tailscale hostname instead of the public IP means dev access works even if you later remove SSH from the public firewall entirely (max-hardening option for client boxes).

## 2. Server-side toolchain (as `<DEV_USER>` unless noted)

### 2.1 PHP 8.4 + Composer
Ubuntu 24.04 ships PHP 8.3, so add the standard PPA (needs sudo → run via `<ADMIN_USER>` or add to the Ansible `base` role — preferred):

```bash
sudo add-apt-repository ppa:ondrej/php -y && sudo apt update
sudo apt install -y php8.4-cli php8.4-{mbstring,xml,curl,mysql,sqlite3,pgsql,zip,intl,gd,bcmath,redis}
curl -sS https://getcomposer.org/installer | php -- --install-dir=$HOME/.local/bin --filename=composer
```

### 2.2 Node via mise (per-project versions, no sudo)

```bash
curl https://mise.run | sh           # installs to ~/.local; add activation line it prints to ~/.bashrc
mise use -g node@22                  # global default; per-repo .mise.toml overrides
```

**Why mise:** one tool pins Node (and more) *per project* — the agent and you always build with the version the repo declares. (Composer handles PHP deps; PHP binary itself stays apt-managed.)

### 2.3 Git + GitHub CLI

```bash
git config --global user.name "Your Name" && git config --global user.email "you@<DOMAIN>"
sudo apt install -y gh tmux
gh auth login        # device flow; also used by Claude Code for PRs
```

### 2.4 Workspace layout (convention the whole stack shares)

```
/home/<DEV_USER>/projects/
├── <app-1>/          # each repo cloned here
├── <app-2>/
└── infra/            # the Ansible toolkit repo
```

Multica registers `~/projects/*` as workspaces (doc 06); Claude Code runs inside them (doc 04). One layout, three consumers.

## 3. Working practices that matter on this box

- **Deploys go through Git → Coolify, never by editing on the server.** The dev workspace is for writing code; Coolify containers are the runtime. Local preview: `php artisan serve --port 8001` / `npm run dev` and access via VS Code's automatic port forwarding (no firewall holes needed).
- **tmux for anything long-running** (`tmux new -s work`) — survives laptop sleep/disconnects; Claude Code sessions you start manually live here too.
- **Resource awareness:** `htop` is your friend; heavy `npm run build` + a Multica agent run + Coolify build simultaneously will contend on 6 shared vCPUs. Stagger or let it queue.

## 4. Validation

- [ ] VS Code opens `vps-dev`, terminal lands in `/home/<DEV_USER>`.
- [ ] `php -v` → 8.4 · `composer -V` · `node -v` → 22 · `gh auth status` ✓.
- [ ] Clone a repo into `~/projects`, `composer install && npm ci && npm run build` clean.
- [ ] `artisan serve` preview reachable through VS Code port forward.

## 5. Reuse notes

- Everything in §2 belongs in an Ansible `devtools` role (PPA, packages, mise, gh) → any future box becomes a dev box with one tag: `--tags devtools`.
- For client servers, omit this layer entirely (they get apps + agents, not your IDE), or create a scoped `client-dev` user with access only to their repos.
