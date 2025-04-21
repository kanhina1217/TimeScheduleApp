//
//  TimetableWidigetBundle.swift
//  TimetableWidget
//
//  Created by Kyoko Hobo on 2025/04/21.
//

import WidgetKit
import SwiftUI

@main
struct TimetableWidigetBundle: WidgetBundle {
    var body: some Widget {
        TimetableWidget()
        TimetableWidigetControl()
        TimetableWidigetLiveActivity()
    }
}
