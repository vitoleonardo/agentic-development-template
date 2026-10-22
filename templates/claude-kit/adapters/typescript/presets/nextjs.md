---
paths:
  - "app/**"
  - "src/app/**"
  - "**/*.tsx"
  - "proxy.ts"
  - "src/proxy.ts"
  - "middleware.ts"
  - "next.config.*"
---

# Next.js (App Router, Next.js 16)

Version facts were checked against the Next.js 16 upgrade guide on 23.10.2026. Re-check them when upgrading.

## Version facts

- `cookies()`, `headers()`, `draftMode()`, `params` and `searchParams` are async only; synchronous access is removed. Always `await` them.
- `middleware.ts` is deprecated and renamed `proxy.ts`, with the exported function named `proxy`. `proxy` runs on the Node.js runtime only.
- `next lint` is removed, and `next build` no longer lints. Run ESLint or Biome through the `lint` script.
- Cache Components are opt-in with `cacheComponents: true` in `next.config.ts`. With it on, request-time data (`cookies`, `headers`, `searchParams`, uncached fetches) must sit inside `<Suspense>` or the build fails.
- Requires Node.js 20.9+ and TypeScript 5.1+.

## Structure (convention)

- `app/` holds routing and composition only: `page`, `layout`, `loading`, `error`, `not-found`, route handlers. Business logic lives in `features/<domain>/` and data access in `data/` (or the project's equivalent).
- Use private folders (`_components`) for route-local code that must not become a route.

## Server and client boundary

- Components are Server Components by default. Add `'use client'` only for state, effects or browser APIs, and as low in the tree as possible.
- Modules that touch secrets, the database or tokens start with `import 'server-only'`.
- Props passed from a Server to a Client Component are serializable and contain no secrets.
- Only `NEXT_PUBLIC_*` variables reach the browser. Never prefix a secret with `NEXT_PUBLIC_`.

## Data and mutations

- Server Actions and route handlers are public HTTP endpoints. Each one authenticates, authorizes and validates its input itself; never rely on the page that renders the form.
- Keep `'use server'` actions thin: call a `server-only` data-access function that does auth, authorization and the database work.
- After a mutation, revalidate explicitly (`revalidatePath` or `revalidateTag`).
- Write the caching decision for every new data source into the plan: static, cached with revalidation, or dynamic.

## Routing, errors and quality

- Every segment that fetches data has a `loading.tsx` or `<Suspense>` boundary and an `error.tsx`.
- Call `notFound()` for missing resources instead of rendering an empty page with status 200.
- `proxy.ts` does coarse redirects only. Real authorization stays in the data layer.
- Use `next/image`, `next/font`, and `metadata` / `generateMetadata`.
- Accessibility: semantic elements, labelled form controls, keyboard operable, focus managed in dialogs.

## Testing

- Unit-test pure logic and synchronous components with the project's runner. Async Server Components are not supported by Vitest; cover them with E2E tests.
- `next build` is part of verification: it catches static/dynamic and Cache Components errors that typecheck misses.
