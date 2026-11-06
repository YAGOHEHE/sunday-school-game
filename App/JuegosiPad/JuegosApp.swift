import SwiftUI
import JuegosCore
import JuegosUI

@main
struct JuegosApp: App {
    @State private var model = AppModel()
    @State private var play = PlayController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(play)
                #if DEBUG
                .task {
                    // Solo depuración: JUEGOS_AUTOPLAY=1 entra directo al modo juego.
                    if ProcessInfo.processInfo.environment["JUEGOS_AUTOPLAY"] != nil {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        play.startSession(model: model)
                    }
                }
                #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive { model.saveNow() }
        }
    }
}
