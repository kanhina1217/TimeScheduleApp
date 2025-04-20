import UIKit
import CoreData

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // アプリ起動時にCore Dataの設定を行う
        setupCoreData()
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
}