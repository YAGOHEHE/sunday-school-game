import SwiftUI
import JuegosCore

// MARK: - Plantilla Reloj: panel de pasos + reloj grande

struct RelojBody: View {
    @Environment(PlayController.self) private var play
    @Environment(\.playPalette) private var pal
    let game: Game
    let template: PlayTemplate
    let mainIndex: Int
    var presenting: Bool

    var body: some View {
        let side = resolveSide(game: game, template: template, mainIndex: mainIndex)
        HStack(spacing: 40) {
            if side != .none && template.sidePanelLeading { sideView(side) }
            clock.frame(maxWidth: .infinity, maxHeight: .infinity)
            if side != .none && !template.sidePanelLeading { sideView(side) }
        }
        .padding(.horizontal, 48).padding(.vertical, 28)
    }

    @ViewBuilder private func sideView(_ side: ResolvedSide) -> some View {
        if side == .steps {
            StepsBig(game: game, presenting: presenting).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            SideColumn(game: game, side: side, presenting: presenting).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var clock: some View {
        switch game.tools[mainIndex].kind {
        case .timer:
            if let t = play.timerState(mainIndex) { RelojTimer(state: t, presenting: presenting) }
        case .stopwatch:
            if let s = play.stopwatchState(mainIndex) { RelojStopwatch(state: s, presenting: presenting) }
        default:
            ToolBox(index: mainIndex, presenting: presenting)
        }
    }
}

struct StepsBig: View {
    @Environment(\.playPalette) private var pal
    let game: Game
    var presenting: Bool

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 6) {
                        Text(game.category.emoji)
                        Text("\(game.category.name.es.uppercased()) · \(game.category.name.zh)")
                    }
                    .font(Theme.font(14, .semibold)).tracking(1.4).foregroundStyle(pal.accent)
                    BiBlock(l: game.title, esSize: presenting ? 78 : 64, zhSize: 40, esColor: pal.fg, zhColor: pal.fg2,
                            center: false, zhWeight: .bold, lineLimit: 3)
                    BiText(game.objective, size: presenting ? 26 : 21, secondaryOpacity: 0.7)
                        .foregroundStyle(pal.fg.opacity(0.88))
                    StepsList(game: game, big: true)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .leading)
                .frame(maxHeight: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: Temporizador

private struct RelojTimer: View {
    var state: TimerState
    var presenting: Bool
    @Environment(\.playPalette) private var pal
    private var progress: Double { state.total > 0 ? state.remaining / state.total : 0 }

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle().stroke(pal.isLight ? Color(hex: 0xECE8DF) : Color(hex: 0x22222C), lineWidth: 28)
                Circle().trim(from: 0, to: progress)
                    .stroke(state.finished ? Color.red : Theme.ringReloj, style: StrokeStyle(lineWidth: 28, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
                VStack(spacing: 6) {
                    Text(formatTime(state.remaining.rounded(.up)))
                        .font(Theme.font(120, .bold)).monospacedDigit().minimumScaleFactor(0.3).lineLimit(1)
                    if state.finished {
                        LT("¡Tiempo!", "时间到!").font(Theme.font(32, .bold)).foregroundStyle(.red)
                    } else {
                        Text("de \(formatTime(state.total))").font(Theme.font(18)).foregroundStyle(pal.fg2)
                    }
                }
                .padding(50)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: presenting ? 560 : 440, maxHeight: presenting ? 560 : 440)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Quedan \(formatTime(state.remaining.rounded(.up)))")

            if !presenting {
                HStack(spacing: 12) {
                    Button { state.primary() } label: { LT(state.running ? L("Pausa", "暂停") : L("Iniciar", "开始")) }
                        .buttonStyle(PlayButtonStyle(kind: .solid(pal.primary, pal.onPrimary), big: true, capsule: false, radius: 16))
                    Button { state.add(seconds: 60) } label: { Text("+1 min") }
                        .buttonStyle(PlayButtonStyle(kind: .outline(pal.fg), big: true, capsule: false, radius: 16))
                    Button { state.reset() } label: { LT("Reiniciar", "重置") }
                        .buttonStyle(PlayButtonStyle(kind: .outline(pal.fg), big: true, capsule: false, radius: 16))
                    Menu {
                        ForEach(TimerControls.presets, id: \.1) { p in Button(p.0) { state.set(seconds: p.1) } }
                    } label: { Image(systemName: "clock.arrow.2.circlepath").frame(width: 44, height: 44) }
                        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Cambiar duración")
                }
            }
        }
    }
}

// MARK: Cronómetro

private struct RelojStopwatch: View {
    var state: StopwatchState
    var presenting: Bool
    @Environment(\.playPalette) private var pal

    var body: some View {
        let durations: [Double] = state.laps.enumerated().map { i, t in t - (i > 0 ? state.laps[i - 1] : 0) }
        let best = durations.count >= 2 ? durations.min() : nil
        VStack(spacing: 24) {
            Text("VUELTA \(state.laps.count + 1) · 第\(state.laps.count + 1)圈")
                .font(Theme.font(16)).tracking(1.2).foregroundStyle(pal.fg2)
            Text(formatTime(state.elapsed, tenths: true))
                .font(Theme.font(presenting ? 190 : 150, .bold)).monospacedDigit().minimumScaleFactor(0.3).lineLimit(1)
            if !presenting {
                HStack(spacing: 12) {
                    Button { state.primary() } label: { LT(state.running ? L("Parar", "停") : L("Iniciar", "开始")) }
                        .buttonStyle(PlayButtonStyle(kind: .solid(pal.primary, pal.onPrimary), big: true, capsule: false, radius: 16))
                    Button { state.lap() } label: { LT("Vuelta", "圈") }
                        .buttonStyle(PlayButtonStyle(kind: .solid(pal.accent, pal.isLight ? .white : Color(hex: 0x0B0B0F)), big: true, capsule: false, radius: 16))
                    Button { state.reset() } label: { LT("Reiniciar", "重置") }
                        .buttonStyle(PlayButtonStyle(kind: .outline(pal.fg), big: true, capsule: false, radius: 16))
                }
            }
            if !durations.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(durations.enumerated().reversed()), id: \.offset) { i, d in
                            HStack {
                                Text("#\(i + 1)").foregroundStyle(pal.fg2)
                                Spacer()
                                Text(formatTime(d, tenths: true)).monospacedDigit().fontWeight(d == best ? .semibold : .regular)
                                Spacer()
                                if d == best {
                                    LT("Récord", "最佳").font(Theme.font(14, .semibold)).foregroundStyle(pal.accent)
                                } else if i > 0 {
                                    let delta = d - durations[i - 1]
                                    Text(String(format: "%@%.1f s", delta < 0 ? "−" : "+", abs(delta))).font(Theme.font(14)).foregroundStyle(pal.fg2)
                                } else {
                                    LT("primera", "第一圈").font(Theme.font(14)).foregroundStyle(pal.fg2)
                                }
                            }
                            .font(Theme.font(20))
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(pal.panel))
                        }
                    }
                }
                .frame(width: 460).frame(maxHeight: 260)
            }
        }
    }
}
