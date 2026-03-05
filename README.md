# LUME - Light Unveils Memory Environment

**LUME** is an immersive, spatial-computing journal that allows users to physically walk through their memory lane using Augmented Reality.

Users can save their best moments to LUME using its elegant diary feature. Unlike traditional 2D diary apps, LUME lets users re-experience these moments by projecting a personalized museum-like AR experience directly into their physical space. 

Each memory entry contains a photo, title, description, and location. From these details, LUME dynamically generates 3D museum display stands and informational placards. Users can easily add a new memory entry by tapping the "+" button in the intuitive split-view interface.

To enter the AR experience, simply tap the **"See in AR"** button. From there, LUME will automatically project your memories around you if they have GPS coordinates attached, or you can manually place the display stands anywhere in your room by tapping flat surfaces. You can walk around and inspect your memories just like artifacts in a real-world museum!

## Technologies Used
- **SwiftUI**: For crafting a fluid, glassmorphic, and highly responsive user interface.
- **RealityKit & ARKit**: Leveraged to project high-fidelity 3D models and dynamically render SwiftUI views into AR materials.
- **MapKit**: To tag memories with real-world spatial coordinates.

## Project Structure
Here is a high-level overview of the core files powering LUME:

```text
📂 LUME
 ├── MyApp.swift                 # Application entry point & Font Registration
 ├── 📂 Views
 │    ├── 📂 Screens
 │    │    ├── LumeIntroView.swift    # Cinematic animated launch screen
 │    │    ├── UnveilStoryView.swift  # Glassmorphic onboarding card
 │    │    ├── HomeScreenView.swift   # Main SplitView hub
 │    │    ├── MemoryView.swift       # Memory editor (Images, Text, MapKit)
 │    │    └── ARMuseumView.swift     # RealityKit/ARKit spatial tracking environment
 │    └── 📂 Components
 │         ├── MemoryCard.swift       # Sidebar list item
 │         ├── PhotoPickerView.swift  # Native PHPicker wrapper
 │         └── CameraView.swift       # Native Camera wrapper
 ├── 📂 ViewModels
 │    └── HomeScreenViewModel.swift   # State management for memory arrays
 └── 📂 Models
      ├── MemoryItem.swift            # Core data structure with CLLocation
      └── OnBoardingModel.swift       # Configuration for intro sequences
```

*Note: I designed LUME with Apple's spatial computing future in mind, bridging the gap between flat journal entries and living, spatial memories. The 3D museum stand models were custom-created specifically for this experience.*