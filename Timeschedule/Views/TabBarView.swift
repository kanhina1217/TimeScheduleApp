import SwiftUI
import CoreData

struct TabBarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 時間割タブ
            NavigationView {
                MainView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem { Label("時間割", systemImage: "calendar") }
            .tag(0)

            // カレンダータブ（特殊時程設定）
            NavigationView {
                SpecialScheduleView()
                    .environment(\.managedObjectContext, viewContext)
            }
            .tabItem { Label("カレンダー", systemImage: "calendar.badge.clock") }
            .tag(1)
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