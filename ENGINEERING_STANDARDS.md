# Engineering Standards

## Architecture

- **MVVM** for the presentation layer: Views (UIViewControllers) render
  state and forward user intent; ViewModels hold presentation state and
  business logic.
- **Repository pattern** as the single source of truth for event data,
  isolating "where did this data come from" (network/cache) from
  both the ViewModels and the persistence/networking implementations.
- **Dependency injection** : all concrete types are constructed in exactly one place; everything else
  depends on protocols.
  This is what makes the app testable without a DI framework.

## Concurrency

- Swift Concurrency (`async/await`) throughout; no completion-handler.
- `TTLCache` Time-to-live threshold before loading data from api.
- UI-facing types  are `@MainActor` so state observed by UIKit is
  always mutated on the main thread — no `DispatchQueue.main.async`
  scattered through the codebase.

## Error handling

- Every network failure has a defined fallback (see `EventsRepository`):
  degrade to cached/disk data and surface an "offline" indicator, never
  a blank screen or an unhandled crash.
- Core Data writes  `try`/error to manage errors.

## Testing

- Business logic (`NetworkManagerProtocol`, `EventsRepositoryProtocol`, `CoreDataStoreProtocol`)
  is tested against protocol fakes / an in-memory Core Data stack — no
  test hits the real network or writes to the real on-disk store.
- Tests follow `test_<unit>_<scenario>_<expectedOutcome>` naming for
  readability without needing to open the test body to know intent.

## Resource usage

- **Memory:** `NSCache` for the in-memory image tier
  — it auto-evicts under memory pressure.
- **Network:** TTL cache avoids redundant refetches within a 10-minute
  window; background refresh is deliberately low-frequency
  (`BGAppRefreshTask`, ~hourly, system-scheduled).
- **Background tasks:** scoped to a single `BGAppRefreshTask` — no runaway timers or
  unbounded background execution.

## Code quality / style

- No third-party dependencies. Everything (image cache, TTL cache,
  networking) 
