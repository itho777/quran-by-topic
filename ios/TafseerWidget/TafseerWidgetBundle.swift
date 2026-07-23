import WidgetKit
import SwiftUI

@main
struct TafseerWidgetBundle: WidgetBundle {
    var body: some Widget {
        AyahWidget()
        PrayerC1Widget()
        PrayerC2Widget()
        PrayerC4Widget()
        LastReadWidget()
    }
}
