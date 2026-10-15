<h1 align="center">
  <br>
  <img src="https://upload.wikimedia.org/wikipedia/commons/9/9d/Swift_logo.svg" alt="Swift Logo" width="120">
  <br>
  LUME
  <br>
</h1>

<h4 align="center">An immersive, spatial-computing journal built for the <strong>WWDC Swift Student Challenge</strong>.</h4>

<p align="center">📖 <strong>New to the code?</strong> Read <a href="HOW_IT_WORKS.md"><strong>How LUME Works</strong></a> — every technology used on iPad and Apple Vision Pro, explained in plain words.</p>

<div align="center">

[About The Project](#about-the-project) • [The Experience](#the-experience) • [Technical Architecture](#technical-architecture) • [App Audit & Analysis](#app-audit--analysis) • [How To Run](#how-to-run) • [Acknowledgements](#acknowledgements)

</div>

---

## About The Project

**LUME (Light Unveils Memory Environment)** is an experiential journal built entirely in a Swift App Playground. It challenges the traditional concept of 2D diaries by allowing users to physically walk through their "memory lane" using Augmented Reality.

As users create entries—attaching photos, stories, and real-world GPS coordinates—LUME seamlessly transforms these flat memories into a living, spatial museum. The app dynamically generates 3D display stands and informational placards, projecting a personalized museum-like AR experience directly into the user's physical space. 

## The Experience

1. **The Hub:** The app opens to a fluid, glassmorphic split-view interface where you can browse your timeline of memories.
2. **The Capture:** Add new entries using the camera or photo library, write your story, and pin the exact location of the memory using interactive **MapKit** integration.
3. **The Projection:** Tap the "See in AR" button to transition from local 2D viewing into an immersive 3D space.
4. **The Museum:** Your environment becomes the canvas. LUME uses **ARKit** and device heading math to auto-place memories around you based on their real-world GPS coordinates, or you can manually place your custom 3D museum stands on any flat surface via raycasting.

## Technical Architecture

This project is built using native Apple frameworks, prioritizing a clean MVVM structure and pushing the limits of SwiftUI and RealityKit integration.

### File Structure

```text
📂 L-U-M-E (repo)
 ├── README.md
 ├── wwdc_audit_report.md.resolved (Original audit)
 └── 📂 LUME-1.swiftpm  ← open this in Xcode
      ├── Package.swift (App Playground manifest — iPad only)
      ├── MyApp.swift (App Entry Point & Custom Font Registration)
      ├── 📂 Views
      │    ├── 📂 Screens
      │    │    ├── LumeIntroView.swift (Cinematic Launch Sequence)
      │    │    ├── UnveilStoryView.swift (Glassmorphic Onboarding, drag-to-tilt card)
      │    │    ├── HomeScreenView.swift (Main Hub: SplitView, search, swipe/context actions)
      │    │    ├── MuseumView.swift (Full-screen museum UI: status, memory carousel)
      │    │    └── ARMuseumView.swift (MuseumController: AR session, GPS podiums, 3D preview)
      │    ├── 📂 Components
      │    │    ├── MemoryCard.swift (Sidebar row)
      │    │    ├── MemoryView.swift (Memory Editor & MapKit pinning)
      │    │    ├── DescriptionContainerView.swift (Museum placard → AR texture)
      │    │    ├── ImageContainerView.swift (Framed print → AR texture)
      │    │    ├── PhotoPickerView.swift (PHPickerViewController Wrapper)
      │    │    └── CameraView.swift (UIImagePickerController Wrapper)
      │    └── 📂 Modifiers (Button styles, transitions)
      ├── 📂 ViewModels
      │    └── HomeScreenViewModel.swift (Central State, ID-based selection, auto-save)
      ├── 📂 Services
      │    ├── LocationManager.swift (CoreLocation wrapper)
      │    └── MemoryStore.swift (On-disk persistence)
      ├── 📂 Models
      │    └── MemoryItem.swift (Memory + location helpers + persistence record)
      ├── 📂 Resources (chosen-stand.usdz podium model, Komorebi font)
      └── 📂 Assets.xcassets (Images, App Icon)
```

### Core Components

- **SwiftUI & UIKit Interoperability:** `NavigationSplitView` hub with native `UIViewControllerRepresentable`s for Camera and Photo Library access.
- **MVVM Design Pattern:** `HomeScreenViewModel` owns the memories and the selected memory **ID** (never a raw index), and auto-saves to disk.
- **RealityKit & ARKit:** `MuseumController` runs world tracking with `gravityAndHeading` alignment, so −Z is true north and GPS bearings map straight into the room. Podiums stand on the detected floor, face the viewer, and can be moved, rotated and resized with gestures.
- **Dynamic AR Materials:** SwiftUI's `ImageRenderer` turns the placard and framed photo into textures, cached per memory so re-placing a podium never re-renders.
- **Custom Typography:** The Komorebi font is registered from embedded data in `MyApp.swift`, so it also renders inside AR textures.

## How To Run (Xcode)

1. Open **`LUME-1.swiftpm`** in Xcode (double-click it, or *File ▸ Open…*). It must be opened as the `.swiftpm` package for Xcode to treat it as an app.
2. Pick an **iPad** run destination — the app is iPad-only (iPadOS 17+).
3. For a real iPad: in the target's *Signing & Capabilities*, choose your team, then plug in the iPad and press **Run**.
4. Grant **Camera** and **Location** when asked.
5. Create a memory, pin it on the map, then tap **Enter Memory Museum** and slowly scan the floor.

> AR needs a physical iPad. In the Simulator (or on iPads without world tracking) the museum opens as an interactive **3D preview gallery** — drag to look around, pinch to zoom, tap a card or podium to focus it.

### Using the museum

- **GPS memories** (pinned on the map) appear automatically once the floor is found: each podium stands in the real compass direction of where the memory happened, with its distance on the placard (e.g. *“1.2 km away · NE”*). Real distances are compressed so even far-away places land within a few steps.
- **Other memories:** pick one in the bottom carousel, then tap the floor to raise its podium. Tap again elsewhere to move it.
- **Podium gestures:** drag to move, pinch to resize, twist to rotate. Long-press a carousel card to remove its podium; ↺ resets the room.
- **Photo markers:** pointing the iPad at a printed memory photo shows a miniature podium on it.

## App Audit — what was fixed

All items from `wwdc_audit_report.md.resolved` have been addressed:

| Audit finding | Fix |
| :--- | :--- |
| ❌ `chosen-stand` model not bundled — AR showed nothing | `Resources` is now declared in `Package.swift`; the model ships in the app and loads asynchronously, with a procedural fallback podium if it ever fails. |
| ⚠️ Force-unwrapped `Binding($vm.selectedIndex)!` crash risk | Selection is tracked by memory **ID**; the editor gets an ID-based binding that can't go out of bounds (delete while editing is safe). |
| ⚠️ Whole array passed to every `MemoryCard` | Sidebar uses `List(selection:)`; each card only receives its own memory. |
| ⚠️ `ForEach(id: \.self)` re-identified rows on every keystroke | Rows are identified by `MemoryItem.id`. |
| ⚠️ Texture regeneration on every tap | Placard/photo textures are rendered once per memory and cached; render scale reduced from 2× to 1×. |
| Duplicate location-string logic | Moved to `MemoryItem.locationString`. |
| Camera option crashed on devices without a camera | Camera is only offered when available. |
| `@ObservedObject` view model could be recreated (data loss) | Now `@StateObject`; memories persist across launches. |
| Low-detail photos could break the AR session as detection images | Reference images are validated first; the session recovers if one is rejected. |

## Future Improvements & Known Issues
- GPS placement relies on the compass (`gravityAndHeading`); near strong magnetic interference the direction can be off by a few degrees — tap ↺ to recalibrate.
- Location-anchored AR (`ARGeoTrackingConfiguration`) could make outdoor placement exact in supported cities.

## Acknowledgements

* Made specifically for Apple's WWDC Swift Student Challenge.
* Custom Font: "Komorebi" used for spatial and cinematic typography.
* 3D Assets: Custom modelled museum display stands created in Blender over a week of intensive study.
* Special thanks to the Swift Club Parul University.

---
> Designed with ❤️ by Manav in India.