import SwiftUI
import CoreData

struct TabBarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // ホームタブ（今日と明日の予定）
            NavigationStack {
                HomeView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem { Label("ホーム", systemImage: "house") }
            .tag(0)
            
            // 時間割タブ
            NavigationStack {
                MainView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem { Label("時間割", systemImage: "calendar") }
            .tag(1)

            // カレンダータブ（特殊時程設定）
            NavigationStack {
                SpecialScheduleView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem { Label("カレンダー", systemImage: "calendar.badge.clock") }
            .tag(2)
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().standardAppearance = appearance
        }
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}