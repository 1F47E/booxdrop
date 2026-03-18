import SwiftUI

@main
struct BooxDropApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("BooxDrop")
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 500)
    }
}
