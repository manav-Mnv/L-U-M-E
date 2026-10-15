import SwiftUI
import PhotosUI
import MapKit

/// The visionOS memory editor: title, photo (from the library — apps can't use the
/// Vision Pro cameras), story and map pin.
struct VisionMemoryEditor: View {
    @Binding var memoryItem: MemoryItem
    var onShowInMuseum: () -> Void
    var onDelete: () -> Void

    @EnvironmentObject private var locationManager: LocationManager

    @State private var photoSelection: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isConfirmingDelete = false
    @State private var isWaitingForLocation = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header

                HStack(alignment: .top, spacing: 28) {
                    photoCard
                        .frame(width: 360)
                    storyEditor
                }

                locationSection

                museumCallToAction
            }
            .padding(40)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Memory", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
        .confirmationDialog("Delete this memory?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Memory", role: .destructive, action: onDelete)
        } message: {
            Text("This can't be undone.")
        }
        .onChange(of: photoSelection) { _, item in
            loadPhoto(item)
        }
        .onAppear {
            if let coordinate = memoryItem.coordinate {
                cameraPosition = .region(region(around: coordinate))
            }
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
                .foregroundStyle(.secondary)

            TextField("Give this memory a title", text: $memoryItem.title, axis: .vertical)
                .font(.extraLargeTitle)
        }
    }

    private var photoCard: some View {
        // The picker's label isn't main-actor isolated, so hand it plain values.
        let image = memoryItem.image
        let isLoading = isLoadingPhoto
        return VStack(spacing: 12) {
            PhotosPicker(selection: $photoSelection, matching: .images) {
                PhotoTile(image: image, isLoading: isLoading)
            }
            .buttonStyle(.plain)

            if memoryItem.image != nil {
                Button(role: .destructive) {
                    withAnimation { memoryItem.image = nil }
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        }
    }

    private var storyEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Story", systemImage: "text.quote")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("What happened? Who was there? How did it feel?", text: $memoryItem.body, axis: .vertical)
                .lineSpacing(4)
                .lineLimit(12...)
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

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
                    MapCompass()
                    MapScaleView()
                }
                .onTapGesture { position in
                    if let coordinate = proxy.convert(position, from: .local) {
                        pin(coordinate, recenter: false)
                    }
                }
            }
            .frame(height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .top) {
                if memoryItem.coordinate == nil {
                    Label("Look at a spot on the map and pinch to pin it", systemImage: "hand.pinch")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassBackgroundEffect()
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 12) {
                Button {
                    useMyLocation()
                } label: {
                    if isWaitingForLocation {
                        ProgressView()
                    } else {
                        Label("Use My Location", systemImage: "location.fill")
                    }
                }
                .disabled(locationManager.isDenied)

                if memoryItem.coordinate != nil {
                    Button(role: .destructive) {
                        withAnimation { memoryItem.coordinate = nil }
                    } label: {
                        Label("Remove Pin", systemImage: "mappin.slash")
                    }
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

    private var museumCallToAction: some View {
        Button(action: onShowInMuseum) {
            HStack(spacing: 20) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 36, weight: .semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text("See it in the Tabletop Museum")
                        .font(.title3.weight(.semibold))
                    Text(memoryItem.coordinate == nil
                         ? "Its podium turns to face you on the tabletop."
                         : "In the walk-through museum it stands in the direction of where it happened.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 28))
    }

    // MARK: - Helpers

    private var wordCount: Int {
        memoryItem.body.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingPhoto = true
        Task {
            defer {
                isLoadingPhoto = false
                photoSelection = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            withAnimation { memoryItem.image = image.preparedForMemory() }
        }
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

/// The photo area of the editor; tapping it opens the Photos picker.
private struct PhotoTile: View {
    let image: UIImage?
    let isLoading: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.thinMaterial)
            .frame(height: 440)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 52, weight: .light))
                        Text("Add a Photo")
                            .font(.title3.weight(.semibold))
                        Text("From your photo library")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 28, style: .continuous))
            .hoverEffect(.lift)
    }
}
