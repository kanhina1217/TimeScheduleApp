//
//  TimescheduleApp.swift
//  Timeschedule
//
//  Created by Kyoko Hobo on 2025/04/17.
//

import SwiftUI

@main
struct TimescheduleApp: App {
    // CoreDataの永続コントローラーを初期化
    let persistenceController = PersistenceController.shared

    // AppDelegateをSwiftUIで使う場合
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
