import SwiftUI

struct ImageContainerView: View {
    let uiImage: UIImage?
    var locationString: String? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.white
            
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("No Image")
                    .font(.largeTitle)
                    .frame(maxHeight: .infinity)
            }
            
            if let locationString {
                HStack {
                    Text("📍")
                    Text(locationString)
                }
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 60)
                .padding(.vertical, 30)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(.top, 120)
            }
        }
        .ignoresSafeArea()
        .frame(width: 1536, height: 2048)
        .background(.white)
    }
}
