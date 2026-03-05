import SwiftUI

struct DescriptionContainerView: View {
    let title: String
    let description: String
    var locationString: String? = nil
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: 80, weight: .semibold, design: .rounded))
                
                Spacer().frame(height: 48)
                
                Text(description)
                    .font(.system(size: 40, design: .rounded))
                
                Spacer()
                
                if let locationString {
                    HStack {
                        Text("📍")
                        Text(locationString)
                    }
                    .font(.system(size: 50, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 60)
                }
            }
            .padding(.top, 240)
            .frame(width: 1280, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .padding(128)
        .frame(width: 2048, height: 1536)
        .background(.white)
    }
}
