# RU Access Plan

Date: 2026-03-30
Project: DocuTranslate

## Goal

Keep only one public domain:

- `docutranslate.ru`

No visible `ru.` subdomain for users.

Russian users should reach the site through `212.28.182.235`, while other users may keep the current route.

## Target Flow

Main idea:

`Russian user -> docutranslate.ru -> Cloudflare edge geo steering -> 212.28.182.235 -> 107.174.231.22:2053 -> DocuTranslate`

Default idea for non-Russian users:

`Other user -> docutranslate.ru -> Cloudflare edge geo steering -> current path -> DocuTranslate`

## What Changes

- We do not create `ru.docutranslate.ru` as the user-facing solution.
- We keep `docutranslate.ru` as the only public hostname.
- We introduce same-domain routing by region.

## What Stays The Same

- App stays on `107.174.231.22:2053`
- Current origin app stack stays the same
- Basic auth stays on origin unless a separate reason appears

## Required Decision

We must choose how `docutranslate.ru` will route users differently by region.

Possible mechanisms:

- GeoDNS or geolocation routing at DNS provider level
- `Cloudflare` load balancing or steering only if it supports the requirement cleanly
- Another front-door service if current provider path blocks the design

## Compared Options

### Option A: GeoDNS

How it would work:

- `docutranslate.ru` would answer different IPs by country
- RU resolvers would get `212.28.182.235`
- non-RU resolvers would get the current path
- the routing decision would happen during DNS resolution

Pros:

- simple mental model
- same public hostname stays unchanged
- can work without application changes

Cons:

- country choice depends on resolver geography or ECS support, not on the final user request
- DNS cache makes rollback and failover slower
- it fits worse with the current orange-cloud `Cloudflare` front door because the decision happens before the proxied HTTP request reaches the edge
- debugging is harder because DNS answers and actual user geography can diverge

### Option B: `Cloudflare` proxied load balancer with geo steering

How it would work:

- keep `docutranslate.ru` as the only public hostname
- create a proxied `Cloudflare` load balancer on `docutranslate.ru`
- define an RU pool that targets `212.28.182.235`
- define a default pool that keeps the current path to `107.174.231.22:2053`
- use geo steering so RU traffic prefers the RU pool and other traffic prefers the default pool
- the routing decision happens at the `Cloudflare` edge when the proxied request is handled
- keep the zone in the proxied front-door model instead of switching the primary design to DNS-only answers

Pros:

- better match for the current `Cloudflare`-fronted setup
- same-domain steering stays at the front door instead of depending on recursive DNS behavior
- faster rollback and failover than DNS-only routing because the decision is request-time, not TTL-bound
- more accurate country steering for proxied HTTP traffic than resolver-based GeoDNS

Cons:

- requires `Cloudflare` Load Balancing, which is an add-on even on a Free zone
- later cards still need a valid RU-side TLS and proxy path on `212.28.182.235`

## Chosen Mechanism

Choose `Cloudflare` proxied load balancing with geo steering as the primary same-domain steering mechanism.

Reason:

- the product goal is one visible hostname, not a separate RU subdomain
- the current production entry already depends on `Cloudflare`
- the routing decision should happen on proxied HTTP traffic at the edge, not in resolver-dependent DNS answers
- this gives the cleanest path to `RU -> 212.28.182.235` and `non-RU -> current path` without changing the user-visible URL

GeoDNS stays only as a fallback idea if the load-balancing add-on cannot be enabled, but it is not the chosen implementation path for this plan.

## Final Routing Scheme

- Public hostname: `docutranslate.ru`
- Routing decision point: `Cloudflare` edge load balancer on the proxied request
- Primary front door mode: proxied `Cloudflare`, not DNS-only GeoDNS
- RU path: `docutranslate.ru -> Cloudflare geo steering -> 212.28.182.235 -> reverse proxy -> https://107.174.231.22:2053`
- Default path: `docutranslate.ru -> Cloudflare geo steering -> current path -> https://107.174.231.22:2053`
- No user-facing `ru.` subdomain at any stage

## Hard Requirement

- Russian users should still open `docutranslate.ru`
- not `ru.docutranslate.ru`
- not another visible subdomain

## Important Technical Consequence

If Russian users are sent directly to `212.28.182.235` while keeping hostname `docutranslate.ru`, then server `212.28.182.235` must be able to serve TLS for:

- `docutranslate.ru`

This is more strict than the old subdomain idea.

## Best Practical Plan

### Step 1

Choose same-domain steering method for `docutranslate.ru`.

Need clear answer for:

- how Russian users are detected: `Cloudflare` geo steering by country
- where the routing decision happens: `Cloudflare` edge load balancer
- what default non-Russian path remains: the current path to `107.174.231.22:2053`

### Step 2

Prepare `212.28.182.235` as RU path:

- reverse proxy to `https://107.174.231.22:2053`
- preserve headers
- do not duplicate auth unless necessary

### Step 3

Prepare TLS for `docutranslate.ru` on the RU path.

### Step 4

Enable geo steering so:

- RU -> `212.28.182.235`
- non-RU -> current path

### Step 5

Validate:

- browser
- curl
- Playwright
- proxy path
- second VPS
- ideally real Russian network

## Current Constraints

- SSH to `almaz@212.28.182.235` works
- `nginx`, `docker`, `certbot` exist on `212`
- `80` is already busy on `212`
- `443` is free on `212`
- no good root or sudo path yet

## Phase 2 Capability Snapshot For `212.28.182.235`

Check date: `2026-03-30`

Observed directly over SSH:

- `ssh -i /home/pets/.ssh/docutranslate_ru_proxy almaz@212.28.182.235` works
- active login user is `almaz`
- host reports as `vmi2303558.contaboserver.net`
- `docker` is installed and usable by `almaz`
- `nginx` binary exists on the host
- `certbot` binary exists on the host
- `ss -ltnp` shows `0.0.0.0:80` and `[::]:80` already occupied
- no listener is present on `443` at the time of the check
- `sudo -n true` fails, so there is no passwordless sudo path for this work

Operational consequence:

- do not base the RU path on editing system `nginx`
- do not base the RU path on `certbot` HTTP-01 on `80`
- treat Docker as the only practical operator surface available to `almaz`

## Chosen Launch Shape On `212.28.182.235`

Use a dedicated Docker-managed reverse proxy as the RU entry service.

Why this shape wins:

- it works with the confirmed `almaz` + Docker permissions
- it avoids touching the already busy host port `80`
- it does not depend on root access to install or rewire system services
- it keeps the rollback boundary narrow because one container can be stopped without changing the origin app

Concrete shape:

- keep the existing host services on `80` untouched
- publish only `443:443` from the RU proxy container
- store proxy config and certificate material in the `almaz` home directory
- set the container restart policy to `unless-stopped`
- point the upstream at `https://107.174.231.22:2053`
- preserve host and forwarding headers at the proxy layer

Rejected for this plan:

- system `nginx` reconfiguration, because there is no confirmed root path
- `certbot` HTTP-01 on `80`, because `80` is already occupied
- a second public hostname for RU traffic, because the user-facing domain must remain `docutranslate.ru`

## Phase 2 Reverse Proxy Configuration

Chosen proxy runtime:

- use `nginx:alpine` inside Docker on `212.28.182.235`
- bind only `443:443`
- mount one explicit config file plus one certificate directory from the `almaz` home directory

Suggested container launch:

```bash
docker run -d \
  --name docutranslate-ru-proxy \
  --restart unless-stopped \
  -p 443:443 \
  -v /home/almaz/docutranslate-ru-proxy/default.conf:/etc/nginx/conf.d/default.conf:ro \
  -v /home/almaz/docutranslate-ru-proxy/certs:/etc/nginx/certs:ro \
  nginx:1.29-alpine
```

Suggested `/home/almaz/docutranslate-ru-proxy/default.conf`:

```nginx
server {
    listen 443 ssl http2;
    server_name docutranslate.ru;

    ssl_certificate /etc/nginx/certs/docutranslate.ru.crt;
    ssl_certificate_key /etc/nginx/certs/docutranslate.ru.key;

    location / {
        proxy_pass https://107.174.231.22:2053;
        proxy_http_version 1.1;
        proxy_ssl_server_name on;
        proxy_ssl_verify off;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
    }
}
```

Required behavior for this proxy:

- preserve the original `Host` header as `docutranslate.ru`
- forward `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`, and `X-Forwarded-Host`
- keep the upstream on `https://107.174.231.22:2053`
- leave origin basic auth behavior unchanged instead of adding a second auth wall on the RU proxy
- keep `/health` behavior unchanged because the origin already exposes it without auth

Why `proxy_ssl_verify off` is part of the plan:

- the current origin path on `107.174.231.22:2053` already uses a self-signed certificate
- this mirrors the existing `curl -k` / `Cloudflare Full` operating model instead of introducing a new certificate dependency during proxy bring-up

Smoke commands for the RU proxy itself:

```bash
curl -k --resolve docutranslate.ru:443:212.28.182.235 https://docutranslate.ru/health
curl -k --resolve docutranslate.ru:443:212.28.182.235 -u admin:***** https://docutranslate.ru/
```

## Phase 3 TLS Strategy For `docutranslate.ru` On The RU Path

Public TLS boundary:

- browsers still connect to `docutranslate.ru` through proxied `Cloudflare`
- the browser-facing certificate stays a `Cloudflare` edge concern
- `212.28.182.235` acts as the RU origin behind `Cloudflare`, not as a new user-facing hostname

Origin TLS boundary on `212.28.182.235`:

- the RU proxy container on `212` must terminate TLS for `server_name docutranslate.ru`
- the mounted certificate pair should live at:
  - `/home/almaz/docutranslate-ru-proxy/certs/docutranslate.ru.crt`
  - `/home/almaz/docutranslate-ru-proxy/certs/docutranslate.ru.key`

Bootstrap certificate strategy for the current environment:

- use a self-signed certificate for `docutranslate.ru` on the RU proxy first
- this is acceptable because the current `Cloudflare` zone is already in `Full`, not `Strict`
- this avoids dependence on `certbot` HTTP-01, which is blocked by the occupied `80` port and lack of root
- direct origin checks should continue to use `curl -k`

Concrete bootstrap command:

```bash
mkdir -p /home/almaz/docutranslate-ru-proxy/certs
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /home/almaz/docutranslate-ru-proxy/certs/docutranslate.ru.key \
  -out /home/almaz/docutranslate-ru-proxy/certs/docutranslate.ru.crt \
  -subj "/CN=docutranslate.ru" \
  -addext "subjectAltName=DNS:docutranslate.ru"
```

Upgrade path if the zone is later moved to `Strict` or if direct browser access to the RU origin becomes necessary:

- replace the self-signed pair with a `Cloudflare Origin CA` certificate for `docutranslate.ru`, or
- replace it with a DNS-01-issued public certificate if DNS/API access is available

Cutover rule for this plan:

- do not point the RU pool at `212.28.182.235` until the container answers TLS for `docutranslate.ru` on `443`
- validate that with:

```bash
curl -k --resolve docutranslate.ru:443:212.28.182.235 https://docutranslate.ru/health
openssl s_client -connect 212.28.182.235:443 -servername docutranslate.ru </dev/null
```

## Phase 3 Same-Domain Geo-Routing Cutover

Concrete `Cloudflare` objects to create:

- load balancer hostname: `docutranslate.ru`
- default pool: `docutranslate-default`
- RU pool: `docutranslate-ru`
- health monitor path: `/health`

Pool targets:

- `docutranslate-default` -> current origin path on `107.174.231.22:2053`
- `docutranslate-ru` -> RU proxy on `212.28.182.235:443`

Steering rule:

- steering mode: geo
- country match for RU traffic: `RU`
- RU traffic preference: `docutranslate-ru`
- all other traffic preference: `docutranslate-default`

Host and health assumptions:

- keep the public hostname fixed at `docutranslate.ru`
- use `/health` as the pool health endpoint because it is intentionally outside basic auth
- keep the origin request host aligned with `docutranslate.ru`
- keep the current proxied `Cloudflare` front-door model instead of switching users to any direct RU hostname

Cutover sequence:

1. Confirm the default path is still healthy at `https://107.174.231.22:2053/health`.
2. Confirm the RU proxy answers `https://docutranslate.ru/health` when forced to `212.28.182.235` with `--resolve`.
3. Create `docutranslate-default` and `docutranslate-ru` pools.
4. Attach both pools to the proxied load balancer for `docutranslate.ru`.
5. Enable geo steering so `RU -> docutranslate-ru` and `non-RU -> docutranslate-default`.
6. Re-run the curl and browser validation from both paths before calling the cutover complete.

Hard fallback if the provider path is incomplete:

- if `Cloudflare` Load Balancing cannot be enabled cleanly, do not publish a partial cutover
- keep all user traffic on the current default path
- keep the RU proxy available only for direct validation with `--resolve`
- reopen GeoDNS only as a separate fallback decision, not as a silent substitution for the chosen proxied design

Success condition for this card:

- every user still opens only `docutranslate.ru`
- RU traffic is eligible for `212.28.182.235`
- non-RU traffic keeps the current path
- the rollback boundary remains one steering change, not an application redeploy

## Phase 4 Route Validation Matrix

Validation date: `2026-03-30`

Observed paths:

- local direct path:
  - `curl -k https://docutranslate.ru/health` returned `{"status":"ok","version":"1.7.1.post1"}`
  - `curl -k -u admin:***** https://docutranslate.ru/` returned `HTTP/2 200`
- RU-like authenticated proxy path:
  - `curl -k -u admin:***** https://docutranslate.ru/` returned `HTTP/2 200` when routed through the configured authenticated proxy
- secondary VPS path from `212.28.182.235`:
  - `curl -k https://docutranslate.ru/health` returned `{"status":"ok","version":"1.7.1.post1"}`
  - `curl -k -u admin:***** https://docutranslate.ru/` returned `HTTP/2 200`
- real end-user Russian consumer access was not available in this session, so that remains an external confirmation step after cutover

Repeatable route-aware browser checks:

```bash
E2E_ROUTE_LABEL=default \
E2E_BASE_URL=https://docutranslate.ru \
node scripts/live_landing_confidence.js

E2E_ROUTE_LABEL=ru-like \
E2E_BASE_URL=https://docutranslate.ru \
E2E_PROXY_SERVER=http://proxy.example:3128 \
E2E_PROXY_USERNAME=... \
E2E_PROXY_PASSWORD=... \
node scripts/live_landing_confidence.js
```

Playwright route controls now expected by this repo:

- `E2E_ROUTE_LABEL` labels the run as `default`, `ru-like`, or another explicit path name
- `E2E_PROXY_SERVER` enables browser-level proxy routing for Playwright and the landing confidence script
- `E2E_PROXY_USERNAME` and `E2E_PROXY_PASSWORD` supply authenticated proxy credentials when required
- `E2E_PROXY_BYPASS` optionally excludes domains from proxying

What these checks prove today:

- the main domain is reachable with health and landing responses from the default path
- the same domain is reachable through a proxy-mediated RU-like path
- the extra VPS path can reach the same public hostname without changing the visible URL
- the route-aware browser confidence runner passed `1/1` round for both `default` and `ru-like` labels on `2026-03-30`
- the automation can now record which route was used for each browser confidence run

## Phase 4 Main-Domain Landing Smoke And Confidence

Executed on: `2026-03-30`

Smoke result on `https://docutranslate.ru`:

- `npx playwright test tests/e2e/features/landing.feature --project=chromium` passed `1/1`
- the smoke step confirmed:
  - basic auth credentials were configured for the run
  - no `pageerror` or console errors were emitted during landing initialization
  - `#app`, `project-title`, `workflow-select`, and `new-task-button` were visible
  - the post-click task card exposed the dynamic upload input and visible drop area

Confidence result on `https://docutranslate.ru`:

- `node scripts/live_landing_confidence.js` passed `3/3`
- recorded summary:
  - `routeLabel=main-domain`
  - `authConfigured=true`
  - `confidence=1`
  - `success=true`

## Practical Risk

Without root:

- we may still hit a blocker on TLS or system nginx

## Rollback

If same-domain steering fails:

- remove only the steering rule
- send all traffic back to the current path
- keep `docutranslate.ru` alive

## Validation Checklist

- `docutranslate.ru` remains the only public hostname
- Russian path is different from default path
- TLS works for `docutranslate.ru`
- UI loads fully
- Playwright smoke passes
- rollback is documented
