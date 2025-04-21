import UIKit
import CoreData
import WidgetKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // アプリ起動時にCore Dataの設定を行う
        setupCoreData()
        
        // ウィジェット用のデータを初期化
        setupWidgetData()
        
        return true
    }
    
    // Core Dataの設定
    private func setupCoreData() {
        // ValueTransformerの登録（セキュアなトランスフォーマー）
        registerValueTransformers()
        
        // Core Dataの事前ロード（必要に応じて）
        _ = PersistenceController.shared
    }
    
    // ValueTransformerの登録
    private func registerValueTransformers() {
        // ArrayTransformerが未登録なら登録する
        let transformerName = NSValueTransformerName("ArrayTransformer")
        if ValueTransformer(forName: transformerName) == nil {
            ArrayTransformer.register()
        }
    }
    
    // ウィジェット用データの初期化
    private func setupWidgetData() {
        #if DEBUG
        print("ウィジェットデータの初期化を開始")
        #endif
        
        // PersistenceControllerからコンテキストを取得
        let context = PersistenceController.shared.container.viewContext
        
        // WidgetDataManagerを使用してデータをエクスポート
        WidgetDataManager.shared.exportDataForWidget(context: context)
        
        #if DEBUG
        // デバッグ用：エクスポートされたデータの内容を出力
        WidgetDataManager.shared.printCurrentWidgetData()
        #endif
        
        // ウィジェットを更新
        WidgetCenter.shared.reloadAllTimelines()
    }
}