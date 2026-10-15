//
//  SwiftUIView.swift
//  
//
//  Created by Dimas on 18/04/23.
//

import SwiftUI

struct OnBoardingView: View {
    
    @Binding var hasFinishedOnboarding: Bool
    
    @State var opacity = 1.0
    
    @StateObject var viewModel = OnBoardingViewModel()
    
    let goldColor = Color(red: 1.0, green: 0.84, blue: 0.45)
    
    var body: some View {
        ZStack {
            Image("bg2")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack {
//                if state == .solution {
//                    Text("Introducing Memolane")
//                        .id(state.body)
//                        .transition(.springToTop)
//                        .font(.system(.title3, design: .rounded))
//                        .foregroundColor(.textSecondary)
//                }
                
                // Illustration animation
                ZStack {
                    GeometryReader { geo in
//                        Color.blue // TODO: change to image
                        
                        Image("onboarding-image-1")
                            .resizable()
                            .frame(
                                width: viewModel.state.rawValue >= 3 ? 120 : 200,
                                height: viewModel.state.rawValue >= 3 ? 90 : 150
                            )
                            .position(x: viewModel.state.rawValue >= 3 ? 50 : 100, y: geo.size.height/2 - (viewModel.state.rawValue >= 3 ? 40 : 0))
                            .rotation3DEffect(
                                .degrees(viewModel.state.rawValue >= 3 ? 70 : 0), axis: (x: -0.1, y: 1, z: -0.1)
                            )
                        
//                        Color.green // TODO: change to image
                        Image("onboarding-image-2")
                            .resizable()
                            .frame(
                                width: viewModel.state.rawValue >= 3 ? 120 : 200,
                                height: viewModel.state.rawValue >= 3 ? 90 : 150
                            )
                            .position(x: geo.size.width - (viewModel.state.rawValue >= 3 ? 50 : 100), y: geo.size.height/2 - (viewModel.state.rawValue >= 3 ? 40 : 0))
                            .rotation3DEffect(
                                .degrees(viewModel.state.rawValue >= 3 ? -70 : 0), axis: (x: 0.1, y: 1, z: -0.1)
                            )
                        
//                        RoundedRectangle(cornerSize: .init(width: 10, height: 10))
//                            .frame(width: geo.size.width, height: 10)
//                            .rotation3DEffect(
//                                .degrees(90), axis: (x: 0, y: 0, z: 1)
//                            )
//                            .rotation3DEffect(
//                                .degrees(80), axis: (x: 1, y: 0, z: 0)
//                            )
//                            .position(x: geo.size.width/2, y: geo.size.height - 96)
                        
                        
                        GeometryReader { inner in
                            RoundedRectangle(cornerSize: .init(width: 10, height: 8))
                                .frame(width: geo.size.width, height: 10)
                            
                            RoundedRectangle(cornerSize: .init(width: 10, height: 8))
                                .frame(width: 40, height: 12)
                                .rotationEffect(.degrees(40))
                                .position(x: geo.size.width - 15)
                                .offset(y: -5)
                            
                            RoundedRectangle(cornerSize: .init(width: 10, height: 8))
                                .frame(width: 40, height: 12)
                                .rotationEffect(.degrees(-40))
                                .position(x: geo.size.width - 15)
                                .offset(y: 15)
                        }
                        .foregroundColor(.primaryColor)
                        .frame(
                            width: viewModel.state.rawValue >= 2 ? geo.size.width : 0,
                            height: viewModel.state.rawValue >= 2 ? 12 : 10
                        )
                        .mask(
                                Rectangle()
                                    .frame(
                                        width: viewModel.state.rawValue >= 2 ? geo.size.width : 0,
                                        height: 80
                                    )
                            )
                        .rotation3DEffect(
                            .degrees(viewModel.state.rawValue >= 3 ? -90 : 0), axis: (x: 0, y: 0, z: 1)
                        )
                        .rotation3DEffect(
                            .degrees(viewModel.state.rawValue >= 3 ? 82 : 0), axis: (x: 0.9, y: 0, z: 0)
                        )
                        .position(
                            x: viewModel.state.rawValue >= 2 ? geo.size.width/2 : 0,
                            y: viewModel.state.rawValue >= 3 ? geo.size.height - 96 : geo.size.height - 56
//                                y: geo.size.height - 96
                        )
                        
                        
//                        RoundedRectangle(cornerSize: .init(width: 10, height: 10))
//                            .frame(
//                                width: viewModel.state.rawValue >= 2 ? geo.size.width : 0,
//                                height: viewModel.state.rawValue >= 2 ? 12 : 10
//                            )
//                            .rotation3DEffect(
//                                .degrees(viewModel.state.rawValue >= 4 ? 90 : 0), axis: (x: 0, y: 0, z: 1)
//                            )
//                            .rotation3DEffect(
//                                .degrees(viewModel.state.rawValue >= 4 ? 82 : 0), axis: (x: 0.9, y: 0, z: 0)
//                            )
//                            .position(
//                                x: viewModel.state.rawValue >= 2 ? geo.size.width/2 : 0,
//                                y: viewModel.state.rawValue >= 4 ? geo.size.height - 96 : geo.size.height - 56
////                                y: geo.size.height - 96
//                            )
                    }
                    
                }
                .frame(width: 480, height: 360)
//                .background(.red)
                
                // ---
                
                Text(viewModel.state.body)
                    .multilineTextAlignment(.center)
                    .id(viewModel.state.body)
                    .transition(.springToTop)
                    .font(.custom("KomorebiRegular", size: 36))
                    .foregroundColor(goldColor)
                    .shadow(color: goldColor.opacity(0.3), radius: 5)
                    .frame(width: 700, height: 180)
            }
            
            VStack {
                Spacer()
                
                Text("Tap anywhere to continue")
                    .font(.custom("KomorebiRegular", size: 24))
                    .kerning(1.5)
                    .foregroundColor(goldColor.opacity(0.8))
                    .opacity(opacity)
                    .onAppear {
                        let baseAnimation = Animation.linear(duration: 0.6)
                        let repeated = baseAnimation.repeatForever()
                        
                        withAnimation(repeated) {
                            opacity = 0.5
                        }
                    }
                    .padding(.bottom, 40)
            }
        }
        .onTapGesture {
            var finished = hasFinishedOnboarding
            withAnimation(Animation.easeOut(duration: 0.25)) {
                viewModel.advanceState(hasFinished: &finished)
            }
            if finished != hasFinishedOnboarding {
                hasFinishedOnboarding = finished
            }
        }
        
    }
}

struct OnBoardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnBoardingView(hasFinishedOnboarding: .constant(false))
    }
}
