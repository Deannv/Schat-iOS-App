//
//  SecureJournalistAppApp.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 17/02/26.
//

import SwiftUI
import CoreData

@main
struct SecureJournalistApp: App {
    let persistenceController = PersistenceController.shared
    @AppStorage("isOnboarding") var isOnboarding: Bool = true
    
    var body: some Scene {
        WindowGroup {
            if isOnboarding {
                OnboardingView()
            } else {
                TabView {
                    HomeView()
                        .tabItem {
                            Label("Pesan", systemImage: "message.fill")
                                .foregroundStyle(.black)
                        }
                    ProfileView()
                        .tabItem {
                            Label("Profil", systemImage: "person.fill")
                                .foregroundStyle(.black)
                        }
                }
                .tint(.black)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
