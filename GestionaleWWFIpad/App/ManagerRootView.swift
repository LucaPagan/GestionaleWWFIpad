//
//  ManagerRootView.swift
//  WWFChallenge7
//
//  Created by Luca Pagano on 06/05/26.
//


import SwiftUI

struct ManagerRootView: View {
    @EnvironmentObject var managerSession: ManagerSession
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapEditorView()
                .tabItem {
                    Label("Mappa", systemImage: "map.fill")
                }
                .tag(0)


            GamificationAdminView()
                .tabItem {
                    Label("Gamification", systemImage: "rosette")
                }
                .tag(1)

            EventBuilderListView()
                .tabItem {
                    Label("Eventi", systemImage: "calendar.badge.clock")
                }
                .tag(2)

            ManagerSettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(Color("WWFGreen"))
    }
}
