//
// ContentView.swift
// Maitool
//
// Created by Luminous on 2024/7/2.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ScoreView()
                .tabItem {
                    Label("查分", systemImage: "list.dash")
                }

            SongsView()
                .tabItem {
                    Label("歌曲", systemImage: "music.note")
                }

            RatingView()
                .tabItem {
                    Label("Rating计算", systemImage: "function")
                }
            
            UserView()
                .tabItem {
                    Label("用户", systemImage: "person")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let userManager = UserManager()
        ContentView()
            .environmentObject(userManager)
    }
}
