import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    // URLスキーム通知用の通知名
    static let continueIterationNotification = Notification.Name("ContinueIterationNotification")

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        // SwiftUIのルートビュー
        let mainView = MainView()

        // ウィンドウにUIHostingControllerを設定
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: mainView)
            self.window = window
            window.makeKeyAndVisible()
        }
        
        // URLでアプリが起動された場合の処理
        if let urlContext = connectionOptions.urlContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }
    
    // URLでアプリが起動されたときの処理
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let urlContext = URLContexts.first {
            handleIncomingURL(urlContext.url)
        }
    }
    
    // URLの処理ロジック
    private func handleIncomingURL(_ url: URL) {
        // URLスキームの確認
        guard url.scheme == "timeschedule" else { return }
        
        // パスによる処理の分岐
        if url.host == "continue-iteration" {
            // 反復処理継続の確認ダイアログを表示する通知を発行
            NotificationCenter.default.post(
                name: Self.continueIterationNotification,
                object: nil
            )
        }
    }
}