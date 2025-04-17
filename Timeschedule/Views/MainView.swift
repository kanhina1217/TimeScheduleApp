import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            // 時間割機能
            Text("時間割機能の画面")
                .tabItem {
                    Image(systemName: "calendar")
                    Text("時間割")
                }
            
            // 教科・タスク管理
            Text("教科・タスク管理の画面")
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("教科・タスク")
                }
            
            // 出席管理
            Text("出席管理の画面")
                .tabItem {
                    Image(systemName: "checkmark.seal")
                    Text("出席管理")
                }
            
            // カスタマイズ機能
            Text("カスタマイズの画面")
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("カスタマイズ")
                }
            
            // データ管理
            Text("データ管理の画面")
                .tabItem {
                    Image(systemName: "externaldrive")
                    Text("データ管理")
                }
            
            // 通知機能
            Text("通知機能の画面")
                .tabItem {
                    Image(systemName: "bell")
                    Text("通知")
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
