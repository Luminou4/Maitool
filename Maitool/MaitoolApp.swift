//
//  MaitoolApp.swift
//  Maitool
//
//  Created by Luminous on 2024/7/2.
//

import SwiftUI
import SwiftData

@main
struct MaitoolApp: App {
    @StateObject private var userManager = UserManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
