import SwiftUI
import AppKit
import JuegosCore
import JuegosUI

@main
struct JuegosMacApp: App {
    @State private var model = AppModel()
    @State private var play = PlayController()
    @Environment(\.openWindow) private var openWindow

    init() {
        // Al ejecutarse con `swift run` (sin bundle) la app necesita activarse como app normal.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Juegos Dominical · 主日学游戏", id: "main") {
            RootView()
                .environment(model)
                .environment(play)
                .frame(minWidth: 1100, minHeight: 700)
                .modifier(LaunchArgs(model: model, play: play))
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.saveNow()
                }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(model.t("Nuevo juego", "新游戏")) { model.newGame() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu(model.t("Sesión", "课程")) {
                Button(model.t("Empezar sesión", "开始课程")) { play.startSession(model: model) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.session.items.isEmpty)
                Button(model.t("Proyector", "投影")) { openWindow(id: "projector") }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button(model.t("Plantillas de juego…", "游戏模板…")) { model.openTemplates() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Divider()
                Picker(model.t("Idioma", "语言"), selection: Binding(get: { model.language }, set: { model.language = $0 })) {
                    Text("Español").tag(LanguageMode.es)
                    Text("中文").tag(LanguageMode.zh)
                    Text("ES + 中文").tag(LanguageMode.both)
                }
            }
        }

        Window("Proyector · 投影", id: "projector") {
            ProjectorView()
                .environment(model)
                .environment(play)
                .frame(minWidth: 640, minHeight: 400)
                .background(ProjectorWindowMover())
        }
    }
}

/// Mueve la ventana a la pantalla externa (si existe) y la pone a pantalla completa.
struct ProjectorWindowMover: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { [weak v] in
            guard let window = v?.window else { return }
            let screens = NSScreen.screens
            guard screens.count > 1 else { return }
            let main = NSScreen.main ?? screens[0]
            let external = screens.first { $0 != main } ?? screens[1]
            window.setFrame(external.frame, display: true)
            if !window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}


/// Argumentos solo para pruebas: `--play <id> [--tool <n>]`, `--projector`, `--touch-save`.
struct LaunchArgs: ViewModifier {
    let model: AppModel
    let play: PlayController
    @Environment(\.openWindow) private var openWindow
    @State private var done = false

    func body(content: Content) -> some View {
        content.task {
            guard !done else { return }
            done = true
            let a = CommandLine.arguments
            func value(_ k: String) -> String? { a.firstIndex(of: k).flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil } }
            #if DEBUG
            if a.contains("--demo-session") {
                model.persistenceDisabled = true
                var sess = Session(date: Date(), title: "Sesión de hoy", availableMinutes: 60)
                for (id, m) in [("sillas-invisibles", 5), ("quien-viene-detras", 15), ("mimica", 10), ("boom", 5)] where model.game(id) != nil {
                    sess.items.append(SessionItem(gameID: id, minutes: m))
                }
                model.session = sess
                model.selectedGameID = "mimica"
            }
            if a.contains("--templates") {
                model.persistenceDisabled = true
                if model.userData.templates.isEmpty {
                    var t = PlayTemplate.tarjeta
                    t.id = "tpl-demo"; t.name = L("Concurso por equipos", "团队竞赛")
                    t.background = .dark; t.sidePanel = .tool(.scoreboard); t.sidePanelLeading = false
                    model.saveTemplate(t)
                }
                model.openTemplates(focus: value("--templates").flatMap { $0.hasPrefix("-") ? nil : $0 } ?? "tpl-demo")
            }
            if a.contains("--editor-modo"), let g = model.game(value("--editor-modo") ?? "") { model.persistenceDisabled = true; model.edit(g) }
            if let id = value("--play"), let g = model.game(id) {
                play.play(g)
                if let t = value("--tool").flatMap(Int.init) { play.toolIndex = t }
            }
            if a.contains("--challenge") { play.rollChallenge(from: model.challenges) }
            if a.contains("--draw") { if model.userData.roster.isEmpty { model.addStudent("Ana"); model.addStudent("Wei") }; play.openDraw() }
            if a.contains("--projector") { openWindow(id: "projector") }
            if a.contains("--touch-save") { model.userData.roster.append("Prueba"); model.saveNow() }
            #endif   // todos los argumentos de prueba existen solo en DEBUG
        }
    }
}
