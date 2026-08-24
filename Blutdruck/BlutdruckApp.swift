import SwiftUI

@main
struct BlutdruckApp: App {
    @StateObject private var speicher = Speicher()
    var body: some Scene {
        WindowGroup {
            Uebersicht().environmentObject(speicher)
        }
    }
}
