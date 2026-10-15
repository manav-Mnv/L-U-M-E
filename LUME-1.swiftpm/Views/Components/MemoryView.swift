import SwiftUI
import PhotosUI
import MapKit

/// The editor for a single memory: title, photo, story and map pin.
struct MemoryView: View {
    @Binding var memoryItem: MemoryItem
    var onViewInAR: () -> Void
    var onDelete: () -> Void

    @EnvironmentObject private var locationManager: LocationManager

    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var isConfirmingDelete = false
    @State private var isWaitingForLocation = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    private let isCameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) {
                        photoCard
                            .frame(width: 340)
                        storyEditor
                    }
                    .frame(minWidth: 640)

                    VStack(alignment: .leading, spacing: 24) {
                        photoCard
                        storyEditor
                    }
                }

                locationSection

                arCallToAction
            }
            .padding(32)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.backgroundSecondary.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: onViewInAR) {
                    Label("View in AR", systemImage: "arkit")
                }
                Menu {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Memory", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete this memory?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Memory", role: .destructive, action: onDelete)
        } message: {
            Text("This can't be undone.")
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPickerView(selectedImage: imageBinding)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraView(selectedImage: imageBinding)
                .ignoresSafeArea()
        }
        .onAppear {
            if let coordinate = memoryItem.coordinate {
                cameraPosition = .region(region(around: coordinate))
            }
            // Only stream location silently if the user already granted it; otherwise ask on "Use My Location".
            if locationManager.authorizationStatus != .notDetermined {
                locationManager.start()
            }
        }
        .onChange(of: locationManager.location) { _, location in
            guard isWaitingForLocation, let location else { return }
            isWaitingForLocation = false
            pin(location.coordinate, recenter: true)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(memoryItem.createdAt.formatted(date: .complete, time: .omitted).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Color.primaryColor)

            TextField("Give this memory a title", text: $memoryItem.title, axis: .vertical)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textPrimary)
        }
    }

    private var photoCard: some View {
        Menu {
            Button {
                isShowingPhotoPicker = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
            if isCameraAvailable {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }
            if memoryItem.image != nil {
                Divider()
                Button(role: .destructive) {
                    withAnimation { memoryItem.image = nil }
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        } label: {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.primaryColor.opacity(0.08))
                .frame(height: 420)
                .overlay {
                    if let image = memoryItem.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 48, weight: .light))
                            Text("Add a Photo")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                            Text(isCameraAvailable ? "From your library or camera" : "From your photo library")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(Color.primaryColor)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    if memoryItem.image == nil {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.primaryColor.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if memoryItem.image != nil {
                        Label("Change", systemImage: "pencil")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(14)
                    }
                }
                .shadow(color: .black.opacity(memoryItem.image == nil ? 0 : 0.15), radius: 16, y: 8)
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var storyEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Story", systemImage: "text.quote")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("What happened? Who was there? How did it feel?", text: $memoryItem.body, axis: .vertical)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .lineSpacing(4)
                .lineLimit(10...)
                .padding(18)
                .background(Color.backgroundPrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06))
                )

            Text("\(wordCount) words")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Location", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let locationString = memoryItem.locationString {
                    Text(locationString)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }

            MapReader { proxy in
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    if let coordinate = memoryItem.coordinate {
                        Marker(memoryItem.displayTitle, systemImage: "sparkles", coordinate: coordinate)
                            .tint(Color.primaryColor)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        pin(coordinate, recenter: false)
                    }
                }
            }
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .top) {
                if memoryItem.coordinate == nil {
                    Label("Tap the map to pin where this happened", systemImage: "hand.tap")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 12) {
                Button {
                    useMyLocation()
                } label: {
                    if isWaitingForLocation {
                        ProgressView()
                            .padding(.horizontal, 28)
                    } else {
                        Label("Use My Location", systemImage: "location.fill")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(locationManager.isDenied)

                if memoryItem.coordinate != nil {
                    Button(role: .destructive) {
                        withAnimation { memoryItem.coordinate = nil }
                    } label: {
                        Label("Remove Pin", systemImage: "mappin.slash")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if locationManager.isDenied {
                    Text("Location access is off — enable it in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var arCallToAction: some View {
        Button(action: onViewInAR) {
            HStack(spacing: 18) {
                Image(systemName: "arkit")
                    .font(.system(size: 34, weight: .semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text("See this memory in AR")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text(memoryItem.coordinate == nil
                         ? "Tap any floor to raise its museum podium."
                         : "Its podium appears in the real direction of where it happened.")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .padding(24)
            .background(
                LinearGradient(colors: [.primaryColor, Color(hex: 0x8B5CF6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .shadow(color: Color.primaryColor.opacity(0.3), radius: 16, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Helpers

    private var imageBinding: Binding<UIImage?> {
        Binding(
            get: { memoryItem.image },
            set: { newImage in
                withAnimation { memoryItem.image = newImage?.preparedForMemory() }
            }
        )
    }

    private var wordCount: Int {
        memoryItem.body.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func region(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, latitudinalMeters: 600, longitudinalMeters: 600)
    }

    private func pin(_ coordinate: CLLocationCoordinate2D, recenter: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            memoryItem.coordinate = coordinate
        }
        if recenter {
            withAnimation(.easeInOut(duration: 0.8)) {
                cameraPosition = .region(region(around: coordinate))
            }
        }
    }

    private func useMyLocation() {
        if let location = locationManager.location {
            pin(location.coordinate, recenter: true)
        } else {
            isWaitingForLocation = true
            locationManager.start()
        }
    }
}
