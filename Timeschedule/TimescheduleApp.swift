//
//  TimescheduleApp.swift
//  Timeschedule
//
//  Created by Kyoko Hobo on 2025/04/17.
//

import SwiftUI
import CoreData

// アプリケーションの起動時にCore Data設定を行うためのコード
final class CoreDataSetup {
    static let shared = CoreDataSetup()
    
    func setupCoreData() {
        // ValueTransformerを登録
        registerValueTransformers()
        
        // Core Data設定の強化（必要に応じて）
        enhanceCoreDataConfig()
    }
    
    private func registerValueTransformers() {
        let transformerName = NSValueTransformerName(rawValue: "ArrayTransformer")
        if ValueTransformer(forName: transformerName) == nil {
            ArrayTransformer.register()
        }
    }
    
    private func enhanceCoreDataConfig() {
        // 必要に応じてCore Data設定を強化
        // この時点でPersistenceControllerが初期化される
        let _ = PersistenceController.shared
    }
}

@main
struct TimescheduleApp: App {
    // AppDelegateをSwiftUIで使う場合
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 初期化時にCore Data設定を行う
    init() {
        CoreDataSetup.shared.setupCoreData()
    }

    // CoreDataの永続コントローラーを初期化
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            TabBarView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
