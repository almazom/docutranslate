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
