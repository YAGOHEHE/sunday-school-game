import SwiftUI
import JuegosCore

// MARK: - Temporizador

struct TimerToolView: View {
    var state: TimerState
    var presenting: Bool

    private var progress: Double { state.total > 0 ? state.remaining / state.total : 0 }
    private var ringColor: Color {
        if state.finished { return .red }
        return progress < 0.2 ? .orange : .mint
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 24)
                Circle().trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
                VStack(spacing: 4) {
                    Text(formatTime(state.remaining.rounded(.up)))
                        .font(bigFont(120, .heavy)).monospacedDigit()
                        .minimumScaleFactor(0.4).lineLimit(1)
                    if state.finished {
                        T("¡Tiempo!", "时间到!").font(bigFont(36, .bold)).foregroundStyle(.red)
                    }
                }
                .padding(40)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 420, maxHeight: 420)
            .padding(8)

            if !presenting { TimerControls(state: state) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
    }
}

struct TimerControls: View {
    var state: TimerState
    var compact = false
    static let presets: [(String, Int)] = [("0:30", 30), ("1:00", 60), ("2:00", 120), ("5:00", 300), ("10:00", 600)]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(Self.presets, id: \.1) { p in
                    Button(p.0) { state.set(seconds: p.1) }
                        .buttonStyle(PillButtonStyle(color: .white, filled: false))
                }
                Button("+30s") { state.add(seconds: 30) }
                    .buttonStyle(PillButtonStyle(color: .white, filled: false))
            }
            HStack(spacing: 14) {
                Button { state.primary() } label: {
                    Label(state.running ? "Pausa · 暂停" : "Iniciar · 开始", systemImage: state.running ? "pause.fill" : "play.fill")
                }
                .buttonStyle(PillButtonStyle(color: state.running ? .orange : .green, big: true))
                Button { state.reset() } label: { Label("Reiniciar · 重置", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(PillButtonStyle(color: .white, big: true, filled: false))
            }
        }
    }
}

/// Temporizador compacto de la cabecera del modo juego.
struct CompactClock: View {
    var state: TimerState
    @Environment(\.playPalette) private var pal
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer").foregroundStyle(pal.fg.opacity(0.6)).accessibilityHidden(true)
            Text(formatTime(state.remaining.rounded(.up)))
                .font(Theme.font(28, .bold)).monospacedDigit().lineLimit(1).fixedSize()
                .foregroundStyle(state.finished ? .red : pal.fg)
            Button { state.primary() } label: {
                Image(systemName: state.running ? "pause.fill" : "play.fill").frame(width: Theme.minTap, height: Theme.minTap).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(pal.fg)
            .accessibilityLabel(state.running ? "Pausar reloj" : "Iniciar reloj")
            Button { state.reset() } label: {
                Image(systemName: "arrow.counterclockwise").frame(width: Theme.minTap, height: Theme.minTap).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(pal.fg.opacity(0.7))
            .accessibilityLabel("Reiniciar reloj")
            Menu {
                ForEach(TimerControls.presets, id: \.1) { p in Button(p.0) { state.set(seconds: p.1) } }
                Button("+1:00") { state.add(seconds: 60) }
            } label: { Image(systemName: "chevron.down.circle").frame(width: Theme.minTap, height: Theme.minTap) }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("Duraciones del reloj")
        }
        .padding(.leading, 18).padding(.trailing, 4)
        .background(Capsule().fill(pal.isColored ? Color.black.opacity(0.22) : pal.panel))
    }
}

// MARK: - Cronómetro

struct StopwatchToolView: View {
    var state: StopwatchState
    var presenting: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text(formatTime(state.elapsed, tenths: true))
                .font(bigFont(150, .heavy)).monospacedDigit()
                .minimumScaleFactor(0.3).lineLimit(1)
            if !presenting {
                HStack(spacing: 14) {
                    Button { state.primary() } label: {
                        Label(state.running ? "Parar · 停" : "Iniciar · 开始", systemImage: state.running ? "pause.fill" : "play.fill")
                    }.buttonStyle(PillButtonStyle(color: state.running ? .orange : .green, big: true))
                    Button { state.lap() } label: { Label("Vuelta · 圈", systemImage: "flag.fill") }
                        .buttonStyle(PillButtonStyle(color: .blue, big: true))
                    Button { state.reset() } label: { Label("Reiniciar · 重置", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(PillButtonStyle(color: .white, big: true, filled: false))
                }
            }
            if !state.laps.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(state.laps.enumerated().reversed()), id: \.offset) { i, t in
                            let prev = i > 0 ? state.laps[i - 1] : 0
                            HStack {
                                Text("#\(i + 1)").foregroundStyle(.white.opacity(0.6))
                                Spacer()
                                Text(formatTime(t - prev, tenths: true)).monospacedDigit()
                                Text("(\(formatTime(t, tenths: true)))").monospacedDigit().foregroundStyle(.white.opacity(0.5))
                            }
                            .font(bigFont(24, .medium))
                        }
                    }
                    .frame(maxWidth: 500)
                }
                .frame(maxHeight: 220)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Marcador

struct ScoreboardToolView: View {
    @Bindable var state: ScoreboardState
    var presenting: Bool
    private let palette: [Color] = [.red, .blue, .green, .orange, .purple, .pink, .teal, .yellow]

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ForEach(Array(state.teams.indices), id: \.self) { i in
                    let color = palette[i % palette.count]
                    VStack(spacing: 14) {
                        if presenting {
                            Text(state.teams[i].name).font(bigFont(34, .bold)).lineLimit(1).minimumScaleFactor(0.5)
                        } else {
                            TextField("Equipo", text: $state.teams[i].name)
                                .textFieldStyle(.plain).multilineTextAlignment(.center)
                                .font(bigFont(28, .bold))
                        }
                        Text("\(state.teams[i].score)")
                            .font(bigFont(120, .heavy)).monospacedDigit()
                            .minimumScaleFactor(0.3).lineLimit(1)
                            .contentTransition(.numericText())
                        if !presenting {
                            HStack(spacing: 12) {
                                Button { withAnimation { state.teams[i].score -= 1 } } label: { Image(systemName: "minus") }
                                    .buttonStyle(PillButtonStyle(color: .white, big: true, filled: false))
                                Button { withAnimation { state.teams[i].score += 1 } } label: { Image(systemName: "plus") }
                                    .buttonStyle(PillButtonStyle(color: color, big: true))
                            }
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, maxHeight: 460)
                    .background(RoundedRectangle(cornerRadius: 28).fill(color.opacity(0.28)))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(color, lineWidth: 3))
                }
            }
            if !presenting {
                HStack(spacing: 12) {
                    Button { state.removeTeam() } label: { Label("Quitar equipo · 减少", systemImage: "person.badge.minus") }
                    Button { state.addTeam() } label: { Label("Añadir equipo · 增加", systemImage: "person.badge.plus") }
                    Button { withAnimation { state.resetScores() } } label: { Label("Poner a cero · 清零", systemImage: "arrow.counterclockwise") }
                }
                .buttonStyle(PillButtonStyle(color: .white, filled: false))
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Boom

struct BoomToolView: View {
    @Bindable var state: BoomState
    var presenting: Bool

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                if state.isBoom {
                    VStack(spacing: 0) {
                        Text("💥").font(.system(size: 120))
                        Text("¡BOOM!").font(bigFont(150, .black)).foregroundStyle(.yellow)
                            .minimumScaleFactor(0.4).lineLimit(1)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("\(state.n)").font(bigFont(300, .heavy)).monospacedDigit()
                        .minimumScaleFactor(0.3).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 36).fill(state.isBoom ? Color.red.opacity(0.55) : Color.white.opacity(0.07)))
            .animation(.spring(duration: 0.25), value: state.isBoom)

            if !presenting {
                HStack(spacing: 18) {
                    Button { state.primary() } label: { Label("Siguiente · 下一个", systemImage: "forward.fill") }
                        .buttonStyle(PillButtonStyle(color: .green, big: true))
                    Button { state.reset() } label: { Label("Reiniciar · 重置", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(PillButtonStyle(color: .white, big: true, filled: false))
                    Divider().frame(height: 30)
                    Stepper(value: $state.multiple, in: 2...20) {
                        Text("Múltiplo · 倍数: \(state.multiple)").font(bigFont(18, .medium))
                    }.fixedSize()
                    Toggle("Incluir dígito · 含数字", isOn: $state.includeDigit)
                        .toggleStyle(.switch).fixedSize()
                }
            } else {
                Text("Múltiplo · 倍数 \(state.multiple)").font(bigFont(22, .medium)).opacity(0.6)
            }
        }
        .foregroundStyle(.white)
        .padding(24)
    }
}

// MARK: - Secuencia de código

struct CodeSequenceToolView: View {
    @Bindable var state: CodeSequenceState
    var presenting: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 28) {
            if state.sequence.isEmpty {
                Text("Pulsa «Generar» para crear una secuencia\n点击“生成”创建密码").font(bigFont(30, .medium))
                    .multilineTextAlignment(.center).opacity(0.7)
            } else if state.hidden {
                VStack(spacing: 10) {
                    Text("🙈").font(.system(size: 120))
                    Text("Secuencia oculta · 已隐藏").font(bigFont(34, .bold)).opacity(0.7)
                }
            } else {
                HStack(spacing: 22) {
                    ForEach(Array(state.sequence.enumerated()), id: \.offset) { _, step in
                        VStack(spacing: 8) {
                            Text(step.signal.symbol).font(.system(size: 110))
                            Text("× \(step.count)").font(bigFont(70, .heavy))
                            Text(step.signal.name.text(model.language)).font(bigFont(22, .medium)).opacity(0.7)
                        }
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 28).fill(.white.opacity(0.1)))
                    }
                }
            }
            if !presenting {
                HStack(spacing: 14) {
                    Button { state.generate() } label: { Label("Generar · 生成", systemImage: "dice") }
                        .buttonStyle(PillButtonStyle(color: .green, big: true))
                    Button { state.hidden.toggle() } label: {
                        Label(state.hidden ? "Mostrar · 显示" : "Ocultar · 隐藏", systemImage: state.hidden ? "eye" : "eye.slash")
                    }
                    .buttonStyle(PillButtonStyle(color: .blue, big: true))
                    .disabled(state.sequence.isEmpty)
                    Stepper(value: $state.length, in: 1...8) {
                        Text("Longitud · 长度: \(state.length)").font(bigFont(18, .medium))
                    }.fixedSize()
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
