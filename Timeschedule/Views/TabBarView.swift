import SwiftUI
import CoreData

struct TabBarView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView {
            // 時間割タブ
            MainView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("時間割", systemImage: "calendar")
                }
            
            // カレンダータブ（特殊時程設定）
            SpecialScheduleView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("カレンダー", systemImage: "calendar.badge.clock")
                }
        }
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}