<h1 align="center">
  <br>
  <img src="https://upload.wikimedia.org/wikipedia/commons/9/9d/Swift_logo.svg" alt="Swift Logo" width="120">
  <br>
  LUME
  <br>
</h1>

<h4 align="center">An immersive, spatial-computing journal built for the <strong>WWDC Swift Student Challenge</strong>.</h4>

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
📂 LUME
 ├── MyApp.swift (App Entry Point & Custom Font Registration)
 ├── 📂 Views
 │    ├── 📂 Screens
 │    │    ├── LumeIntroView.swift (Cinematic Launch Sequence)
 │    │    ├── UnveilStoryView.swift (Glassmorphic Onboarding)
 │    │    ├── HomeScreenView.swift (Main Hub & SplitView)
 │    │    ├── MemoryView.swift (Memory Editor & MapKit Integration)
 │    │    └── ARMuseumView.swift (RealityKit AR Session)
 │    └── 📂 Components
 │         ├── MemoryCard.swift (List Item UI)
 │         ├── DescriptionContainerView.swift (SwiftUI to AR Material Renderer)
 │         ├── ImageContainerView.swift (SwiftUI to AR Material Renderer)
 │         ├── PhotoPickerView.swift (PHPickerViewController Wrapper)
 │         └── CameraView.swift (UIImagePickerController Wrapper)
 ├── 📂 ViewModels
 │    ├── HomeScreenViewModel.swift (Central State Manager)
 │    └── OnBoardingViewModel.swift (Intro Sequence State Machine)
 ├── 📂 Models
 │    ├── MemoryItem.swift (Data Structure with CLLocation Data)
 │    └── OnBoardingModel.swift
 ├── Package.swift (Swift Playground manifest)
 └── 📂 Assets.xcassets (Visuals, Custom 3D Models)
```

### Core Components

- **SwiftUI & UIKit Interoperability:** Centralized declarative UI utilizing native `UIViewControllerRepresentables` for Camera and Photo Library access to ensure a native iOS feel.
- **MVVM Design Pattern:** `HomeScreenViewModel` controls the global state, memory arrays, and index selection to decouple data processing from the view layer.
- **RealityKit & ARKit:** The `ARViewContainer` handles world tracking and horizontal plane detection. It dynamically scales and places custom `.rcproject` 3D stands based on user interaction or relative GPS bearing coordinates.
- **Dynamic AR Materials:** Instead of static textures, LUME uses SwiftUI's `ImageRenderer` within `@MainActor` Task closures to convert complex SwiftUI views (`DescriptionContainerView`) into `CGImage` data, which is applied at runtime as a `TextureResource` onto the 3D planes.
- **Custom Typography:** Manual loading of encoded Base64 TTF files through `CTFontManagerRegisterGraphicsFont` inside `MyApp.swift` ensures the sophisticated visual identity runs portably without external font installations.

## How To Run

1. Make sure you are using an iPad or Mac running **Xcode** or **Swift Playgrounds**.
2. Download or clone this repository.
3. Open `LUME-1.swiftpm`.
4. Run the project and grant **Camera** and **Location** permissions when prompted to enable the full spatial tracking and MapKit features.
5. Create a memory layout, tap "See in AR", and slowly pan your device to detect the floor.

## App Audit & Analysis

This project underwent a comprehensive App Engine and Runtime Audit to ensure WWDC-level polish, crash prevention, and optimal performance:

- **Cross-File Validation:** Utilizing decoupled state bindings and Environment propagation, the UI reliably stays in sync across the SplitView navigation levels.
- **Performance Profiling:** SwiftUI-to-Texture rendering using `ImageRenderer` is explicitly bounded to MainThread execution tasks, avoiding concurrent ARKit rendering crashes.
- **Crash Defense Mechanisms:** Safe index un-wrapping prevents out-of-bounds array access in SwiftUI view builders during list mutations.
- **Architectural Observations:** The AR Coordinator expertly blends CoreLocation bearing calculations with ARKit's local coordinate space matrix transforms to plot spatial anchors accurately.

## Future Improvements & Known Issues
- ImageRenderer CGImage generation inside the AR scene is resource-intensive. Future updates plan to implement a `[UUID: Material]` caching dictionary to reduce GC overhead when users spawn multiple large memories rapidly.
- Implementing dynamic fallback materials if the custom 3D stand model fails to load from the bundle.

## Acknowledgements

* Made specifically for Apple's WWDC Swift Student Challenge.
* Custom Font: "Komorebi" used for spatial and cinematic typography.
* 3D Assets: Custom modelled museum display stands created in Blender over a week of intensive study.
* Special thanks to the Swift Club Parul University.

---
> Designed with ❤️ by Manav in India.