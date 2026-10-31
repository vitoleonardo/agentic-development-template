---
paths:
  - "**/*.module.ts"
  - "**/*.controller.ts"
  - "**/*.service.ts"
  - "**/*.guard.ts"
  - "**/*.dto.ts"
  - "**/*.entity.ts"
  - "**/*.e2e-spec.ts"
  - "nest-cli.json"
---

# NestJS

## Module structure

- One feature module per domain: `src/<domain>/` with `<domain>.module.ts`, `<domain>.controller.ts`, `<domain>.service.ts`, `dto/` and `entities/`. Generate new modules with the Nest CLI conventions the project already uses.
- A module uses another module's providers only through that module's `exports`, never by importing its internal files.
- A circular dependency between modules (`forwardRef`) is a design smell. Propose moving the shared part into its own module, and ask before adding `forwardRef`.
- Dependencies come in through constructor injection. Never `new` a provider by hand.

## Map

Homes NestJS adds to the Map in `structure.md`.

| Kind | Home | Naming |
|------|------|--------|
| Bootstrap | `src/main.ts`, `src/app.module.ts` | – |
| Feature modules | `src/<domain>/` | `<domain>.module.ts`, `.controller.ts`, `.service.ts`, `dto/`, `entities/` |
| E2E tests | `test/` | `<feature>.e2e-spec.ts` |

## Controllers and services

- Controllers are thin: route decorators, DTO input, one service call, the response. No business logic and no repository access.
- Services hold the logic and are unit-testable without HTTP.
- Throw Nest's built-in HTTP exceptions (`NotFoundException`, `ForbiddenException`, ...) or map domain errors in an exception filter. Never return error objects with status 200.

## Validation and security

- Every request body, query and param has a DTO with `class-validator` decorators (or the project's schema library). The global `ValidationPipe` runs with `whitelist: true`, `forbidNonWhitelisted: true` and `transform: true`.
- Authentication and authorization live in guards (`@UseGuards`) and role or policy decorators, not in `if` checks inside controllers. Ownership checks ("may this user touch this record") live in the service.
- Never return entities directly when they carry sensitive fields. Return a response DTO, or exclude fields with the serializer.
- Configuration comes from `@nestjs/config` with a validation schema. Services read config through `ConfigService`, not `process.env`.

## Duplicates

Constructor parameter lists (`private readonly xRepo: XRepo`, `@Inject(X)`) repeat across services, processors and controllers; that is dependency injection, not shared logic. Add this to `scan` in `.claude/kit.conf`:

```sh
--ignore-pattern 'constructor\s*\((?:[^()]|\([^()]*\))*\)'
```

Measured on the server app of a large open-source NestJS monorepo (jscpd 5.4.2, `--ignore-identifiers`): clones containing a constructor went from 32 to 11, all clones from 499 to 469. The rest are import blocks and class headers around the constructor. `--min-tokens 70` leaves 6 such clones but drops all clones from 499 to 185, real ones included, so prefer the pattern.

## Testing

- Unit tests build the module with `Test.createTestingModule` and override external providers (database, HTTP clients, queues).
- E2E tests live in `test/*.e2e-spec.ts`, boot the app with the real `ValidationPipe` and guards, and call it over HTTP with `supertest`.
- Every guarded route has a test for the denied case.
