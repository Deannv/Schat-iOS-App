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

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Pesan", systemImage: "message.fill")
                    }
                ProfileView()
                    .tabItem {
                        Label("Profil", systemImage: "person.fill")
                    }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
