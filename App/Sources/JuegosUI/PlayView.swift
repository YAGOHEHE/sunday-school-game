import SwiftUI
import JuegosCore

// MARK: - Host de herramienta

struct ToolBody: View {
    @Environment(PlayController.self) private var play
    var index: Int
    var presenting: Bool

    var body: some View {
        if let game = play.game {
            let i = index
            if game.tools.indices.contains(i) {
                toolView(game.tools[i], index: i)
                    .id("\(game.id)#\(i)")
            } else {
                SheetView(game: game, presenting: presenting)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func toolView(_ spec: ToolSpec, index i: Int) -> some View {
        switch spec.kind {
        case .timer:
            TimerToolView(state: play.state(index: i) { TimerState(seconds: spec.seconds ?? 60) }, presenting: presenting)
        case .stopwatch:
            StopwatchToolView(state: play.state(index: i) { StopwatchState() }, presenting: presenting)
        case .scoreboard:
            ScoreboardToolView(state: play.state(index: i) { ScoreboardState(count: spec.teams ?? 2) }, presenting: presenting)
        case .deck:
            DeckToolView(state: play.state(index: i) { CardBagState(kind: .deck, groups: spec.groups ?? []) }, presenting: presenting)
        case .generator:
            GeneratorToolView(state: play.state(index: i) { CardBagState(kind: .generator, groups: spec.groups ?? []) }, presenting: presenting)
        case .reference:
            ReferenceToolView(cards: play.state(index: i) { ReferenceState() }, groups: spec.groups ?? [], presenting: presenting)
        case .boom:
            BoomToolView(state: play.state(index: i) { BoomState(multiple: spec.multiple ?? 7) }, presenting: presenting)
        case .caller:
            CallerToolView(state: play.state(index: i) { CardBagState(kind: .caller, groups: spec.groups ?? []) }, presenting: presenting)
        case .colorFlash:
            ColorFlashToolView(state: play.state(index: i) { CardBagState(kind: .colorFlash, groups: spec.groups ?? []) }, presenting: presenting)
        case .identity:
            IdentityToolView(state: play.state(index: i) { CardBagState(kind: .identity, groups: spec.groups ?? []) }, presenting: presenting)
        case .codeSequence:
            CodeSequenceToolView(state: play.state(index: i) { CodeSequenceState(length: spec.length ?? 4) }, presenting: presenting)
        }
    }
}

/// Ficha del juego en grande (pestaña «Ficha»).
struct SheetView: View {
    @Environment(\.playPalette) private var pal
    let game: Game
    var presenting: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                BiText(game.objective, size: presenting ? 40 : 30, weight: .semibold)
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(game.steps.enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .top, spacing: 16) {
                            Text("\(i + 1)").font(bigFont(24, .heavy)).foregroundStyle(.white).frame(width: 44, height: 44)
                                .background(Circle().fill(game.category.color))
                            BiText(s, size: presenting ? 34 : 26)
                        }
                    }
                }
                if !game.tips.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(game.tips.enumerated()), id: \.offset) { _, t in
                            HStack(alignment: .top) { Text("👉"); BiText(t, size: presenting ? 28 : 22) }.opacity(0.85)
                        }
                    }
                }
            }
            .foregroundStyle(pal.fg)
            .padding(40)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Overlays (reto y sorteo)

struct PlayOverlays: View {
    @Environment(PlayController.self) private var play
    @Environment(AppModel.self) private var model
    var presenting: Bool

    var body: some View {
        ZStack {
            if play.showChallenge, let c = play.challenge {
                backdrop
                VStack(spacing: 28) {
                    Text("🎲").font(.system(size: 90))
                    BiText(c, size: 72, weight: .black, align: .center).minimumScaleFactor(0.3)
                    if !presenting {
                        HStack(spacing: 16) {
                            Button { play.rollChallenge(from: model.challenges) } label: { Label("Otro reto · 换一个", systemImage: "dice") }
                                .buttonStyle(PillButtonStyle(color: .pink, big: true))
                            Button { play.closeOverlays() } label: { Label("Cerrar · 关闭", systemImage: "xmark") }
                                .buttonStyle(PillButtonStyle(color: .white, big: true, filled: false))
                        }
                    }
                }
                .padding(50)
                .frame(maxWidth: 1000)
                .background(RoundedRectangle(cornerRadius: 40).fill(Color(white: 0.14)))
                .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.pink, lineWidth: 4))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
            if play.showDraw {
                backdrop
                DrawPanel(presenting: presenting)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: play.showChallenge)
        .animation(.spring(duration: 0.3), value: play.showDraw)
        .foregroundStyle(.white)
    }

    private var backdrop: some View {
        Color.black.opacity(0.72).ignoresSafeArea()
            .onTapGesture { if !presenting { play.closeOverlays() } }
    }
}

struct DrawPanel: View {
    @Environment(PlayController.self) private var play
    @Environment(AppModel.self) private var model
    var presenting: Bool
    @State private var newName = ""
    @State private var managing = false

    var body: some View {
        VStack(spacing: 22) {
            Text("🎯").font(.system(size: 70))
            Text(play.drawName ?? (model.userData.roster.isEmpty ? "—" : "?"))
                .font(bigFont(120, .black)).minimumScaleFactor(0.3).lineLimit(1)
                .foregroundStyle(play.drawSpinning ? .white.opacity(0.7) : .yellow)
                .contentTransition(.identity)
            if !presenting {
                HStack(spacing: 14) {
                    Button { play.draw(roster: model.userData.roster) } label: { Label("Sortear · 抽签", systemImage: "dice") }
                        .buttonStyle(PillButtonStyle(color: .orange, big: true))
                        .disabled(model.userData.roster.isEmpty)
                    if let n = play.drawName, !play.drawSpinning {
                        Button { play.toggleEliminated(n) } label: {
                            Label(play.eliminated.contains(n) ? "Readmitir · 恢复" : "Eliminar · 淘汰", systemImage: "person.fill.xmark")
                        }.buttonStyle(PillButtonStyle(color: .red, big: true, filled: false))
                    }
                    Button { managing.toggle() } label: { Label("Lista · 名单", systemImage: "list.bullet") }
                        .buttonStyle(PillButtonStyle(color: .white, big: true, filled: false))
                    Button { play.closeOverlays() } label: { Image(systemName: "xmark") }
                        .buttonStyle(PillButtonStyle(color: .white, big: true, filled: false))
                }
                if managing || model.userData.roster.isEmpty { roster }
            }
        }
        .padding(40)
        .frame(maxWidth: 1000)
        .background(RoundedRectangle(cornerRadius: 40).fill(Color(white: 0.14)))
        .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.orange, lineWidth: 4))
    }

    private var roster: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Nombre · 姓名", text: $newName).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
                    .onSubmit(add)
                Button("Añadir · 添加", action: add).buttonStyle(PillButtonStyle(color: .green))
                Button("Reactivar todos · 全部恢复") { play.eliminated = [] }.buttonStyle(PillButtonStyle(color: .white, filled: false))
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                    ForEach(model.userData.roster, id: \.self) { n in
                        let out = play.eliminated.contains(n)
                        HStack(spacing: 6) {
                            Button { play.toggleEliminated(n) } label: {
                                Text(n).strikethrough(out).opacity(out ? 0.4 : 1).lineLimit(1)
                            }.buttonStyle(.plain)
                            Spacer(minLength: 0)
                            Button { model.removeStudent(n) } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain).foregroundStyle(.red.opacity(0.9))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.1)))
                    }
                }
            }
            .frame(maxHeight: 160)
        }
        .font(bigFont(16, .medium))
    }

    private func add() { model.addStudent(newName); newName = "" }
}

// MARK: - Modo juego

public struct PlayView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayController.self) private var play
    #if os(macOS)
    @FocusState private var focused: Bool
    #endif

    public init() {}

    public var body: some View {
        if let game = play.game {
            let template = resolveTemplate(for: game, custom: model.userData.templates)
            ZStack {
                PlayScene(game: game, template: template) {
                    VStack(spacing: 0) {
                        PlayHeader(game: game, template: template, presenting: false)
                        PlayTabs(game: game, template: template).padding(.top, 10)
                        TemplateBody(game: game, template: template, presenting: false)
                        PlayFooter()
                    }
                }
                PlayOverlays(presenting: false)
            }
            .preferredColorScheme(.dark)
            #if os(macOS)
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onAppear { focused = true }
            .onKeyPress(.space) { play.primaryAction(template: template); return .handled }
            .onKeyPress(.rightArrow) { play.next(); return .handled }
            .onKeyPress(.leftArrow) { play.previous(); return .handled }
            .onKeyPress(.escape) {
                if play.showChallenge || play.showDraw { play.closeOverlays() } else { play.exit() }
                return .handled
            }
            #else
            // Táctil: deslizar ← → cambia la carta/palabra; si la herramienta no tiene carta,
            // cambia de juego (Anterior/Siguiente). Prev/Siguiente también en los botones del pie.
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { v in
                        guard !play.showChallenge, !play.showDraw else { return }
                        guard abs(v.translation.width) > 64,
                              abs(v.translation.width) > abs(v.translation.height) * 1.6 else { return }
                        let left = v.translation.width < 0
                        if hasCardAction(game, template) {
                            play.primaryAction(template: template)
                        } else if left { play.next() } else { play.previous() }
                    }
            )
            #endif
        }
    }

    #if os(iOS)
    /// La herramienta activa tiene una acción de «otra carta/palabra» (deslizar para cambiar).
    private func hasCardAction(_ game: Game, _ template: PlayTemplate) -> Bool {
        let idx = play.effectiveIndex(game: game, template: template)
        guard game.tools.indices.contains(idx) else { return false }
        switch game.tools[idx].kind {
        case .generator, .deck, .caller, .colorFlash, .identity, .codeSequence: return true
        default: return false
        }
    }
    #endif
}

// MARK: - Proyector

/// Vista del proyector: misma plantilla que el modo juego, sin controles, espejando el PlayController.
public struct ProjectorView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayController.self) private var play

    public init() {}

    public var body: some View {
        ZStack {
            if let g = play.game {
                let template = resolveTemplate(for: g, custom: model.userData.templates)
                PlayScene(game: g, template: template) {
                    VStack(spacing: 0) {
                        PlayHeader(game: g, template: template, presenting: true)
                        TemplateBody(game: g, template: template, presenting: true)
                            .padding(.bottom, 12)
                    }
                }
                PlayOverlays(presenting: true)
            } else {
                Color(white: 0.05).ignoresSafeArea()
                SessionBoard()
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}

struct SessionBoard: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let s = model.session
        VStack(alignment: .leading, spacing: 24) {
            Text(s.title.isEmpty ? model.t("Sesión de hoy", "今日课程") : s.title).font(bigFont(64, .heavy))
            Text(s.date.formatted(date: .complete, time: .omitted)).font(bigFont(26, .medium)).opacity(0.6)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(s.items.enumerated()), id: \.element.id) { i, item in
                    if let g = model.game(item.gameID) {
                        HStack(spacing: 20) {
                            Text("\(i + 1)").font(bigFont(34, .heavy)).frame(width: 60, height: 60)
                                .background(Circle().fill(g.category.color))
                            Text(g.icon).font(.system(size: 48))
                            BiText(g.title, size: 36, weight: .bold)
                            Spacer()
                            Text("\(item.minutes) min").font(bigFont(30, .semibold)).opacity(0.7)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
