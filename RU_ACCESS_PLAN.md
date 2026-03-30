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

`Russian user -> docutranslate.ru -> geo-steered path -> 212.28.182.235 -> 107.174.231.22:2053 -> DocuTranslate`

Default idea for non-Russian users:

`Other user -> docutranslate.ru -> current path`

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

- how Russian users are detected
- where the routing decision happens
- what default non-Russian path remains

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
