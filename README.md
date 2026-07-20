# Local Events Explorer

A small iOS app that shows nearby events, lets you bookmark the ones you
care about, and gets you directions to them. 

## What it does

- Shows a list of nearby events (title, location, time, photo)
- Lets you bookmark events, and see them again in a separately —
  bookmarks survive an app relaunch
- Tapping an event shows more detail and a "Get Directions" button that
  opens Apple Maps
- If the network is down, you still see the last events
  that loaded successfully.(Because it is stored)
- Refreshes itself quietly in the background every hour or so

## Stack, and why

- **UIKit**, with XIBs for each screen.
- **MVVM** — the view controllers only know about their ViewModel, the
  ViewModel only knows about `EventsRepository`. Nothing above the
  Repository knows or cares whether data came from the network, a
  cache, or the database.
- **Core Data** for the two things that need to persist: bookmarks, and
  a snapshot of the events that loaded successfully (used as the
  offline fallback). The schema is in
  `Persistence/LocalEventsExplorer.xcdatamodeld` — Xcode
  auto-generate the entity classes at the time of creating project.
- **A small custom cache** (`CacheConfiguration` / `ResponseCache`) that
  keeps API responses fresh for 5 minutes, so bouncing between tabs
  doesn't refetch every time. Separate from Core Data on purpose — one
  answers "is this still fresh," the other answers "what's the last
  good data if the network is just down."
- **`ImageDownloader`** does the same idea for images: an in-memory
  cache backed by `NSCache` (auto-evicts under memory pressure).
- **Swift Concurrency** (`async/await`) everywhere, no completion
  handler chains. `ImageDownloader` is `actor`s
  so their shared state can't get corrupted by concurrent access.
- **BGTaskScheduler** for the background refresh — it's the
  Apple-blessed way to do "occasionally wake up and refresh some data,"
  and it respects battery/usage patterns instead of running on a timer.

## Project layout

```
App/
    AppDelegate.swift          
    SceneDelegate.swift
Background/                 BackgroundRefreshManager.swift
Cache/                      CacheConfiguration.swift (TTL Cache)
DataModels/                 Event.swift
Networking/                 NetworkManager, ImageDownloader
Persistence/                CoreDataStack + the .xcdatamodeld
Repository/                 EventsRepository.swift (single source of truth for event data)
Resources/                  MockEvents.json (bundled mock API data)
ViewController/
    EventList/               list screen + table cell
    EventDetail/              detail screen
LocalEventsExplorerTests/
```

## Running it

1. Open the project in Xcode, pick a simulator, hit run.
2. It reads from the bundled `MockEvents.json` by default — no backend
   needed. I have added API code but have not used it for this demo.
3. On first launch, it'll ask for location permission. Say yes to see
   distances and sorting; saying no still works, you just won't see
   distances.

## What I'd do next
Here we can add more functionality to just these 2 screens, which include: search, show distance in list, pull to refresh,message for empty or no bookmarks, bookmark update from detail screen, offline load, Google Map option, and many more.

