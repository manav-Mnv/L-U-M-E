import SwiftUI
import RealityKit
import UIKit

struct MuseumView: View {
    @Environment(\.dismiss) var dismiss
    
    var memoryItems: [MemoryItem]
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    var body: some View {
        ARMuseumView(memories: memoryItems, columnVisibility: $columnVisibility)
            .preferredColorScheme(.light)
    }
}
