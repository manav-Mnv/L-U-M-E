import SwiftUI
import PhotosUI
import MapKit

struct MemoryView: View {
    @Binding var memoryItems: [MemoryItem]
    @Binding var selectedIndex: Int
    
    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingActionSheet = false
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                TextField("Title", text: $memoryItems[selectedIndex].title, axis: .vertical)
                    .foregroundColor(.textPrimary)
                    .font(.system(.title, design: .rounded, weight: .medium))
                
                HStack(alignment: .top, spacing: 32) {
                    Button(action: {
                        isShowingActionSheet = true
                    }) {
                        if let image = memoryItems[selectedIndex].image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300, height: 400)
                                .background(Color.backgroundSecondary)
                                .cornerRadius(16)
                        } else {
                            HStack {
                                Image(systemName: "photo")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                
                                Text("Tap to add image")
                                    .font(.system(.title2, design: .rounded))
                            }
                            .foregroundColor(.primary)
                            .frame(width: 300, height: 400)
                            .background(Color.backgroundSecondary)
                            .cornerRadius(16)
                        }
                    }
                    .confirmationDialog("Choose Image Source", isPresented: $isShowingActionSheet, titleVisibility: .visible) {
                        Button("Camera") {
                            isShowingCamera = true
                        }
                        Button("Photo Library") {
                            isShowingPhotoPicker = true
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                    
                    TextField("Description", text: $memoryItems[selectedIndex].body, axis: .vertical)
                        .foregroundColor(.textSecondary)
                        .font(.system(.body, design: .rounded))
                }
                
                Spacer().frame(height: 16)
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Location")
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink {
                            MuseumView(memoryItems: [memoryItems[selectedIndex]], columnVisibility: .constant(.detailOnly))
                        } label: {
                            HStack {
                                Image(systemName: "arkit")
                                Text("View in AR")
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.primaryColor)
                            .cornerRadius(100)
                        }
                    }
                    
                    MapReader { proxy in
                        Map(position: Binding(
                            get: {
                                if let coord = memoryItems[selectedIndex].coordinate {
                                    return .region(MKCoordinateRegion(center: coord, latitudinalMeters: 500, longitudinalMeters: 500))
                                }
                                return .automatic
                            },
                            set: { _ in }
                        )) {
                            UserAnnotation()
                            
                            if let coord = memoryItems[selectedIndex].coordinate {
                                Marker("Memory Location", coordinate: coord)
                            }
                        }
                        .mapControls {
                            MapUserLocationButton()
                        }
                        .onTapGesture { position in
                            if let coordinate = proxy.convert(position, from: .local) {
                                memoryItems[selectedIndex].coordinate = coordinate
                            }
                        }
                    }
                    .frame(height: 250)
                    .cornerRadius(16)
                }
            }
            .padding()
            .sheet(isPresented: $isShowingCamera) {
                CameraView(selectedImage: $memoryItems[selectedIndex].image)
            }
            .sheet(isPresented: $isShowingPhotoPicker) {
                PhotoPickerView(selectedImage: $memoryItems[selectedIndex].image)
            }
        }
    }
}
