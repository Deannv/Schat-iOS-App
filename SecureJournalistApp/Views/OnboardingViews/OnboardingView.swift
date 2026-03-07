//
//  OnboardingView.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 27/02/26.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("isOnboarding") var isOnboarding: Bool?
    @State var selectedIndex: Int = 0;
    
    private var onboardingContents = [
        "Easy to start, familiar interface.",
        "Easy to add new contact, no sweat!",
        "Easy to get connected, no sign up required!",
        "Easy to chat, protected and private!"
    ]
    
    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(onboardingContents.indices, id: \.self) { index in
                OnboardingItem(
                    content: onboardingContents[index],
                    index: index
                )
                .tag(index)
            }
        }
        .safeAreaInset(edge: .top, content: {
            HStack {
                Image(.logoSquare)
                    .resizable()
                    .frame(width: 40, height: 40)
                Text("Schat")
                    .bold()
            }
            .padding(.top, 80)
        })
        .safeAreaInset(edge: .bottom) {
            bottomControls
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .padding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    
    private var bottomControls: some View {
        VStack {
            indicatorView
            navigationButtons
        }
        .padding()
    }
    
    private var indicatorView: some View {
        HStack(spacing: 8) {
            ForEach(0..<onboardingContents.count, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex
                          ? Color.black
                          : Color.gray.opacity(0.3))
                    .frame(
                        width: index == selectedIndex ? 30 : 8,
                        height: 8
                    )
                    .animation(.spring(), value: selectedIndex)
            }
        }
        .padding(.bottom)
    }
    
    private var navigationButtons: some View {
        HStack(spacing: 10) {

            if selectedIndex > 0 {
                Button {
                    withAnimation {
                        selectedIndex -= 1
                    }
                }label: {
                    CustomButtonView(label: "Back", type: 1)
                }
            }

            if selectedIndex < onboardingContents.count - 1 {
                Button {
                    withAnimation {
                        selectedIndex += 1
                    }
                }label: {
                    CustomButtonView(label: "Next", type: 0)
                }
            } else {
                Button {
                    isOnboarding = false
                }label: {
                    CustomButtonView(label: "Start")
                }
            }
        }
    }
}

private struct OnboardingItem: View {
    var content: String
    var index: Int
    
    var body: some View {
        VStack{
            
            Image("Onboarding\(index+1)")
                .resizable()
                .frame(width: 380, height: 380)
            
            Text(content)
                .font(.title2)
                .bold()
                .frame(width: 200)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.top, 60)
    }
}

#Preview {
    OnboardingView()
}
