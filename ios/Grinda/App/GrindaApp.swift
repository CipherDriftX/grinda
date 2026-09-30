import SwiftUI

@main
struct GrindaApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Palette.field.ignoresSafeArea()
                Image("Lockup").resizable().scaledToFit().frame(width: 220)
            }
        }
    }
}
