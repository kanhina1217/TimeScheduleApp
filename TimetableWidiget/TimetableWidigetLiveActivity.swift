//
//  TimetableWidigetLiveActivity.swift
//  TimetableWidiget
//
//  Created by Kyoko Hobo on 2025/04/21.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TimetableWidigetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TimetableWidigetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimetableWidigetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TimetableWidigetAttributes {
    fileprivate static var preview: TimetableWidigetAttributes {
        TimetableWidigetAttributes(name: "World")
    }
}

extension TimetableWidigetAttributes.ContentState {
    fileprivate static var smiley: TimetableWidigetAttributes.ContentState {
        TimetableWidigetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TimetableWidigetAttributes.ContentState {
         TimetableWidigetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TimetableWidigetAttributes.preview) {
   TimetableWidigetLiveActivity()
} contentStates: {
    TimetableWidigetAttributes.ContentState.smiley
    TimetableWidigetAttributes.ContentState.starEyes
}
