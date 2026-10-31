import SwiftUI
import JuegosCore

// MARK: - Escena: fondo + paleta de la plantilla

struct PlayScene<Content: View>: View {
    @Environment(PlayController.self) private var play
    let game: Game
    let template: PlayTemplate
    var fullscreen = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        let flash = flashName
        let pal = PlayPalette.make(template: template, category: game.category,
                                   flash: FlashPalette.stage(flash), cardAccent: FlashPalette.text(flash))
        ZStack {
            if fullscreen { pal.bg.ignoresSafeArea() } else { pal.bg }
            content()
        }
        .environment(\.playPalette, pal)
        .foregroundStyle(pal.fg)
        .animation(.easeInOut(duration: 0.25), value: flash)
    }

    private var flashName: String? {
        guard template.background == .category,
              let i = game.mainToolIndex(for: template),
              game.tools[i].kind == .colorFlash,
              play.effectiveIndex(game: game, template: template) == i else { return nil }
        return play.bag(i)?.current?.color
    }
}

// MARK: - Panel lateral resuelto

enum ResolvedSide: Equatable {
    case none
    case scoreboard(Int)
    case colorRules(Int)
    case steps
    case tool(Int)
}

func resolveSide(game: Game, template: PlayTemplate, mainIndex: Int?) -> ResolvedSide {
    func idx(_ k: ToolKind) -> Int? { game.tools.firstIndex { $0.kind == k } }
    var r: ResolvedSide = .none
    switch template.sidePanel {
    case .none: break
    case .auto:
        if let i = idx(.scoreboard), i != mainIndex { r = .scoreboard(i) }
        else if let i = idx(.colorFlash) { r = .colorRules(i) }
    case .steps: r = .steps
    case .colorRules: if let i = idx(.colorFlash) { r = .colorRules(i) }
    case .tool(let k):
        if let i = idx(k), i != mainIndex { r = k == .scoreboard ? .scoreboard(i) : .tool(i) }
    }
    if r == .none && template.showSteps { r = .steps }
    return r
}

func sideToolIndex(game: Game, template: PlayTemplate, mainIndex: Int?) -> Int? {
    switch resolveSide(game: game, template: template, mainIndex: mainIndex) {
    case .scoreboard(let i), .tool(let i): return i
    default: return nil
    }
}

func stepsVisible(game: Game, template: PlayTemplate, mainIndex: Int?) -> Bool {
    resolveSide(game: game, template: template, mainIndex: mainIndex) == .steps
}

// MARK: - Cuerpo de la plantilla (zona entre cabecera y pie)

struct TemplateBody: View {
    @Environment(PlayController.self) private var play
    @Environment(\.playPalette) private var pal
    let game: Game
    let template: PlayTemplate
    var presenting: Bool

    var body: some View {
        let idx = play.effectiveIndex(game: game, template: template)
        let main = game.mainToolIndex(for: template)
        Group {
            if idx == -1 {
                SheetView(game: game, presenting: presenting)
            } else if idx != main {
                ToolBox(index: idx, presenting: presenting).padding(.horizontal, 32)
            } else {
                switch template.base {
                case .palabra: PalabraBody(game: game, template: template, mainIndex: idx, presenting: presenting)
                case .reloj: RelojBody(game: game, template: template, mainIndex: idx, presenting: presenting)
                case .tarjeta: TarjetaBody(game: game, template: template, mainIndex: idx, presenting: presenting)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Cabecera

struct PlayHeader: View {
    @Environment(PlayController.self) private var play
    @Environment(\.playPalette) private var pal
    let game: Game
    let template: PlayTemplate
    var presenting: Bool

    var body: some View {
        let main = game.mainToolIndex(for: template)
        let mainKind = main.map { game.tools[$0].kind }
        let relojClock = template.base == .reloj && (mainKind == .timer || mainKind == .stopwatch)
        HStack(spacing: 16) {
            if !presenting {
                Button { play.exit() } label: { Label { LT("Salir", "退出") } icon: { Image(systemName: "xmark") } }
                    .buttonStyle(pal.outline())
                    .accessibilityLabel("Salir del modo juego")
            }
            Text(game.icon).font(.system(size: presenting ? 54 : 40))
            BiText(game.title, size: presenting ? 36 : 26, weight: .bold, secondaryOpacity: 0.85)
            if play.queue.count > 1 { progress }
            Spacer(minLength: 8)
            if let end = endEstimate(main) {
                Text("Fin previsto \(timeOfDay(end))").font(Theme.font(presenting ? 20 : 15)).foregroundStyle(pal.fg2)
            }
            if presenting {
                if play.clock.running || play.clock.finished {
                    Text(formatTime(play.clock.remaining.rounded(.up)))
                        .font(Theme.font(40, .bold)).monospacedDigit()
                        .foregroundStyle(play.clock.finished ? .red : pal.fg)
                }
            } else if !relojClock {
                CompactClock(state: play.clock)
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 16)
        .overlay(alignment: .bottom) { if !pal.isColored { Rectangle().fill(pal.line.opacity(pal.isLight ? 0.7 : 1)).frame(height: 1) } }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0..<play.queue.count, id: \.self) { i in
                Capsule()
                    .fill(i == play.queueIndex ? pal.fg : pal.fg.opacity(i < play.queueIndex ? 0.8 : 0.3))
                    .frame(width: i == play.queueIndex ? 44 : 28, height: 8)
            }
            Text("\(play.queueIndex + 1) / \(play.queue.count)").font(Theme.font(15)).foregroundStyle(pal.fg2).padding(.leading, 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Juego \(play.queueIndex + 1) de \(play.queue.count)")
    }

    /// Hora prevista de fin cuando corre el temporizador de la herramienta o el reloj de la cabecera.
    private func endEstimate(_ main: Int?) -> Date? {
        if let m = main, let t = play.timerState(m), t.running { return Date().addingTimeInterval(t.remaining) }
        if play.clock.running { return Date().addingTimeInterval(play.clock.remaining) }
        if let i = play.game?.tools.firstIndex(where: { $0.kind == .timer }), let t = play.timerState(i), t.running {
            return Date().addingTimeInterval(t.remaining)
        }
        return nil
    }
}

// MARK: - Pestañas de herramientas

struct PlayTabs: View {
    @Environment(PlayController.self) private var play
    @Environment(AppModel.self) private var model
    @Environment(\.playPalette) private var pal
    let game: Game
    let template: PlayTemplate

    var body: some View {
        let main = game.mainToolIndex(for: template)
        let sideTool = sideToolIndex(game: game, template: template, mainIndex: main)
        let showSheet = !stepsVisible(game: game, template: template, mainIndex: main)
        let tools = game.tools.indices.filter { $0 != sideTool }
        let order = (main.map { m in [m] + tools.filter { $0 != m } } ?? tools)
        let entries: [Int] = order + (showSheet && !game.tools.isEmpty ? [-1] : [])
        if entries.count > 1 {
            let current = play.effectiveIndex(game: game, template: template)
            HStack(spacing: 8) {
                ForEach(entries, id: \.self) { i in
                    let label: L = i == -1 ? L("Ficha", "说明") : (game.tools[i].title ?? game.tools[i].kind.label)
                    let symbol = i == -1 ? "book" : game.tools[i].kind.symbol
                    Button { play.toolIndex = i } label: {
                        HStack(spacing: 6) { Image(systemName: symbol); Text(model.language == .zh ? label.text(.zh) : label.text(.es)) }
                    }
                    .buttonStyle(i == current ? AnyButtonStyle(pal.solid()) : AnyButtonStyle(pal.tint()))
                }
                Spacer()
            }
            .padding(.horizontal, 32).padding(.bottom, 10)
        }
    }
}

struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ s: S) { make = { AnyView(s.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// MARK: - Pie

struct PlayFooter: View {
    @Environment(PlayController.self) private var play
    @Environment(AppModel.self) private var model
    @Environment(\.playPalette) private var pal

    var body: some View {
        HStack(spacing: 12) {
            Button { play.previous() } label: { Label { LT("Anterior", "上一个") } icon: { Image(systemName: "chevron.left") } }
                .buttonStyle(pal.outline()).disabled(!play.canPrevious)
            Spacer()
            Button { play.rollChallenge(from: model.challenges) } label: { HStack { Text("🎲"); LT("Reto", "挑战") } }
                .buttonStyle(PlayButtonStyle(kind: pal.isColored ? .solid(.white, Theme.inkFixed) : .outline(Color(hex: 0xF472B6).opacity(pal.isLight ? 0.9 : 1)), capsule: pal.isColored))
            Button { play.openDraw() } label: { HStack { Text("🎯"); LT("Sorteo", "抽签") } }
                .buttonStyle(PlayButtonStyle(kind: pal.isColored ? .solid(.white, Theme.inkFixed) : .outline(Color(hex: pal.isLight ? 0xC2410C : 0xFF8A3D)), capsule: pal.isColored))
            Spacer()
            if play.canNext, play.queueIndex + 1 < play.queue.count {
                let g = play.queue[play.queueIndex + 1]
                Button { play.next() } label: {
                    HStack {
                        Text(model.t("Siguiente: ", "下一个：") + g.title.text(model.language == .zh ? .zh : .es))
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(pal.solid())
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 14)
        .overlay(alignment: .top) { if !pal.isColored { Rectangle().fill(pal.line.opacity(pal.isLight ? 0.7 : 1)).frame(height: 1) } }
    }
}

// MARK: - Paneles laterales

struct SideColumn: View {
    @Environment(PlayController.self) private var play
    @Environment(\.playPalette) private var pal
    let game: Game
    let side: ResolvedSide
    var presenting: Bool

    var body: some View {
        switch side {
        case .none: EmptyView()
        case .scoreboard(let i):
            if let s = play.scoreboardState(i) { ScoreSide(state: s, presenting: presenting) }
        case .colorRules(let i):
            if let b = play.bag(i) { LegendSide(bag: b) }
        case .steps:
            ScrollView { StepsList(game: game, big: false) }
        case .tool(let i):
            ToolBox(index: i, presenting: presenting)
        }
    }
}

struct ScoreSide: View {
    @Bindable var state: ScoreboardState
    var presenting: Bool
    @Environment(\.playPalette) private var pal

    var body: some View {
        GeometryReader { geo in
            let n = max(1, state.teams.count)
            let footer: CGFloat = presenting ? 0 : 52
            let h = max(150, (geo.size.height - footer - CGFloat(n) * 12) / CGFloat(n))
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(state.teams.indices), id: \.self) { i in team(i, height: h) }
                    if !presenting {
                        Menu {
                            Button { state.addTeam() } label: { Label("Añadir equipo · 增加", systemImage: "person.badge.plus") }
                            Button { state.removeTeam() } label: { Label("Quitar equipo · 减少", systemImage: "person.badge.minus") }
                            Button { withAnimation { state.resetScores() } } label: { Label("Poner a cero · 清零", systemImage: "arrow.counterclockwise") }
                        } label: {
                            Label { LT("Marcador", "计分板") } icon: { Image(systemName: "ellipsis.circle") }
                                .font(Theme.font(14, .medium)).frame(maxWidth: .infinity, minHeight: Theme.minTap)
                        }
                        .menuStyle(.borderlessButton).accessibilityLabel("Opciones del marcador")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func team(_ i: Int, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            if presenting {
                Text(state.teams[i].name).font(Theme.font(20, .semibold)).lineLimit(1)
            } else {
                TextField("Equipo", text: $state.teams[i].name)
                    .textFieldStyle(.plain).multilineTextAlignment(.center)
                    .font(Theme.font(17, .semibold)).frame(minHeight: 24)
            }
            Text("\(state.teams[i].score)")
                .font(Theme.font(presenting ? 110 : 80, .bold)).monospacedDigit()
                .minimumScaleFactor(0.3).lineLimit(1).frame(maxHeight: .infinity)
                .contentTransition(.numericText())
            if !presenting {
                HStack(spacing: 12) {
                    Button { withAnimation { state.teams[i].score -= 1 } } label: {
                        Image(systemName: "minus").font(.system(size: 20, weight: .bold)).frame(width: 48, height: 48)
                            .overlay(Circle().stroke(pal.fg.opacity(0.6), lineWidth: 2))
                    }
                    .buttonStyle(.plain).accessibilityLabel("Restar punto a \(state.teams[i].name)")
                    Button { withAnimation { state.teams[i].score += 1 } } label: {
                        Image(systemName: "plus").font(.system(size: 20, weight: .bold)).frame(width: 48, height: 48)
                            .foregroundStyle(pal.bg).background(Circle().fill(pal.fg))
                    }
                    .buttonStyle(.plain).accessibilityLabel("Sumar punto a \(state.teams[i].name)")
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity).frame(height: height)
        .background(RoundedRectangle(cornerRadius: 28).fill(pal.panel))
    }
}

struct LegendSide: View {
    var bag: CardBagState
    @Environment(\.playPalette) private var pal

    var body: some View {
        let cards = bag.groups.flatMap(\.cards)
        VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 0)
            HStack(spacing: 4) { LT("REGLAS DE COLOR", "颜色规则") }
                .font(Theme.font(14, .semibold)).opacity(0.85)
            ForEach(Array(cards.enumerated()), id: \.offset) { _, c in
                let active = bag.current == c
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 10).fill(FlashPalette.swatch(c.color)).frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.5), lineWidth: c.color == "blue" ? 2 : 0))
                    VStack(alignment: .leading, spacing: 2) {
                        LT(c.front).font(Theme.font(17, .bold))
                        if let b = c.back { LT(b).font(Theme.font(14)).fixedSize(horizontal: false, vertical: true) }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(active ? Theme.inkFixed : pal.fg)
                .padding(.horizontal, 18).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 22).fill(active ? Color.white : pal.panel))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(active ? Theme.inkFixed : .clear, lineWidth: 4))
            }
            Spacer(minLength: 0)
        }
    }
}

struct StepsList: View {
    @Environment(\.playPalette) private var pal
    let game: Game
    var big: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: big ? 22 : 12) {
            if !big { HStack { LT("PASOS", "步骤") }.font(Theme.font(14, .semibold)).foregroundStyle(pal.fg2) }
            ForEach(Array(game.steps.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(i + 1)").font(Theme.font(big ? 20 : 17, .bold)).foregroundStyle(pal.accent).frame(width: big ? 26 : 22, alignment: .leading)
                    BiText(s, size: big ? 20 : 16, secondaryOpacity: 0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
