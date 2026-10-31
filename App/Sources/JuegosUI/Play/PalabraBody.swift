import SwiftUI
import JuegosCore

// MARK: - Plantilla Palabra: un elemento enorme en una tarjeta central + «otro»

struct PalabraBody: View {
    let game: Game
    let template: PlayTemplate
    let mainIndex: Int
    var presenting: Bool

    var body: some View {
        let side = resolveSide(game: game, template: template, mainIndex: mainIndex)
        HStack(spacing: 24) {
            if side != .none && template.sidePanelLeading {
                SideColumn(game: game, side: side, presenting: presenting).frame(width: 300)
            }
            PalabraCentral(game: game, template: template, index: mainIndex, presenting: presenting)
            if side != .none && !template.sidePanelLeading {
                SideColumn(game: game, side: side, presenting: presenting).frame(width: 300)
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 8)
    }
}

private struct PalabraCentral: View {
    @Environment(PlayController.self) private var play
    @Environment(\.playPalette) private var pal
    let game: Game
    let template: PlayTemplate
    let index: Int
    var presenting: Bool

    var body: some View {
        let kind = game.tools[index].kind
        switch kind {
        case .generator:
            if let b = play.bag(index) { WordGenerator(bag: b, template: template, presenting: presenting) }
        case .caller:
            if let b = play.bag(index) { WordCaller(bag: b, template: template, presenting: presenting) }
        case .colorFlash:
            if let b = play.bag(index) {
                let gen = game.tools.firstIndex { $0.kind == .generator }.flatMap { play.bag($0) }
                WordColor(bag: b, generator: gen, game: game, template: template, presenting: presenting)
            }
        case .boom:
            if let s = play.boomState(index) { WordBoom(state: s, presenting: presenting) }
        case .codeSequence:
            if let s = play.codeState(index) { WordCode(state: s, presenting: presenting) }
        default:
            ToolBox(index: index, presenting: presenting)
        }
    }
}

// MARK: - Tarjeta blanca común

private struct WhiteCard<Top: View, Center: View, Bottom: View>: View {
    @ViewBuilder var top: () -> Top
    @ViewBuilder var center: () -> Center
    @ViewBuilder var bottom: () -> Bottom
    var body: some View {
        VStack(spacing: 12) {
            top().padding(.horizontal, 28).padding(.top, 24)
            center().frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 40)
            bottom().padding(.horizontal, 28).padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 36).fill(Color.white))
        .foregroundStyle(Theme.inkFixed)
    }
}

private func otherLabel(_ kind: ToolKind) -> (String, String) {
    switch kind {
    case .caller: return ("Otra orden", "下一个口令")
    case .colorFlash: return ("Otro color", "换颜色")
    case .boom: return ("Siguiente número", "下一个数")
    case .codeSequence: return ("Otra secuencia", "换一组")
    default: return ("Otra palabra", "换一个")
    }
}

private struct OtherButton: View {
    @Environment(\.playPalette) private var pal
    let kind: ToolKind
    let action: () -> Void
    var body: some View {
        let (es, zh) = otherLabel(kind)
        Button(action: action) {
            HStack(spacing: 8) {
                LT(es, zh)
                Text("(espacio)").font(Theme.font(14)).opacity(0.6)
            }
        }
        .buttonStyle(PlayButtonStyle(kind: .solid(Theme.inkFixed, .white), big: true, capsule: true))
    }
}

// MARK: Chips de grupo

struct GroupChipsLight: View {
    @Bindable var bag: CardBagState
    var presenting: Bool
    @Environment(\.playPalette) private var pal

    var body: some View {
        if bag.groups.count > 1 {
            FlowLayout(spacing: 6) {
                if bag.hasAllOption { chip(L("Todos", "全部"), bag.groupIndex < 0) { bag.select(-1) } }
                ForEach(Array(bag.groups.enumerated()), id: \.offset) { i, g in
                    chip(g.name, bag.groupIndex == i) { bag.select(i) }
                }
            }
        }
    }

    private func chip(_ l: L, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LT(l).font(Theme.font(14, on ? .semibold : .regular))
                .foregroundStyle(on ? Color.white : Color(hex: 0x3F3C4C))
                .padding(.horizontal, 14).frame(minHeight: presenting ? 32 : Theme.minTap)
                .background(Capsule().fill(on ? pal.cardAccent : Color(hex: 0xF0EDE5)))
        }
        .buttonStyle(.plain).disabled(presenting)
    }
}

private struct RemainingLabel: View {
    let remaining: Int, total: Int
    var body: some View {
        LT("quedan \(remaining) de \(total)", "剩余 \(remaining) / \(total)")
            .font(Theme.font(14)).foregroundStyle(Theme.secondaryFixed)
    }
}

// MARK: Generador

private struct WordGenerator: View {
    @Bindable var bag: CardBagState
    let template: PlayTemplate
    var presenting: Bool
    @Environment(\.playPalette) private var pal

    var body: some View {
        WhiteCard {
            HStack(alignment: .top) {
                GroupChipsLight(bag: bag, presenting: presenting)
                Spacer(minLength: 12)
                RemainingLabel(remaining: bag.remaining, total: bag.cards.count)
            }
        } center: {
            if bag.cards.isEmpty {
                Text("Sin tarjetas · 没有卡片").font(Theme.font(30)).foregroundStyle(Theme.secondaryFixed)
            } else if let c = bag.current {
                VStack(spacing: 14) {
                    BiBlock(l: c.front, esSize: presenting ? 170 : 140, esColor: Theme.inkFixed, zhColor: pal.cardAccent,
                            columns: template.bilingualColumns)
                    if let b = c.back { BiText(b, size: 28, weight: .medium, align: .center).foregroundStyle(Theme.secondaryFixed) }
                }
                .id(bag.rollTick)
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            } else {
                Text("🎲").font(.system(size: 160)).opacity(0.6)
            }
        } bottom: {
            if !presenting { OtherButton(kind: .generator) { bag.next() } }
        }
        .animation(.spring(duration: 0.3), value: bag.rollTick)
        .onAppear { if bag.current == nil, !bag.cards.isEmpty { bag.next() } }
    }
}

// MARK: Llamador

private struct WordCaller: View {
    @Bindable var bag: CardBagState
    let template: PlayTemplate
    var presenting: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.playPalette) private var pal

    var body: some View {
        WhiteCard {
            HStack(alignment: .top) {
                GroupChipsLight(bag: bag, presenting: presenting)
                Spacer(minLength: 12)
                RemainingLabel(remaining: bag.remaining, total: bag.cards.count)
            }
        } center: {
            if bag.cards.isEmpty {
                Text("Sin tarjetas · 没有卡片").font(Theme.font(30)).foregroundStyle(Theme.secondaryFixed)
            } else if let c = bag.current {
                VStack(spacing: 22) {
                    BiBlock(l: c.front, esSize: 120, esColor: Theme.inkFixed, zhColor: pal.cardAccent, columns: template.bilingualColumns)
                    if bag.revealed, let b = c.back {
                        BiBlock(l: b, esSize: 44, zhSize: 36, esColor: pal.cardAccent, zhColor: Theme.secondaryFixed,
                                columns: template.bilingualColumns, esWeight: .semibold, zhWeight: .medium)
                    }
                }
                .id(bag.rollTick)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else {
                Text("📣").font(.system(size: 150)).opacity(0.6)
            }
        } bottom: {
            if !presenting {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        OtherButton(kind: .caller) { bag.next() }
                        if bag.current?.back != nil {
                            Button { bag.revealed.toggle() } label: {
                                Label { LT(bag.revealed ? L("Ocultar acción", "隐藏") : L("Revelar acción", "揭晓")) } icon: { Image(systemName: "eye") }
                            }
                            .buttonStyle(PlayButtonStyle(kind: .outline(Theme.inkFixed), big: true))
                        }
                    }
                    HStack(spacing: 22) {
                        Toggle(isOn: Binding(get: { bag.auto }, set: { bag.setAuto($0) })) { LT("Auto", "自动") }
                            .toggleStyle(.switch).fixedSize()
                        Stepper(value: Binding(get: { bag.interval }, set: { bag.setInterval($0) }), in: 1...60) {
                            LT("cada \(bag.interval) s", "每\(bag.interval)秒").font(Theme.font(15, .medium))
                        }.fixedSize()
                        Toggle(isOn: $bag.speak) { LT("Voz", "语音") }.toggleStyle(.switch).fixedSize()
                    }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: bag.rollTick)
        .animation(.easeInOut, value: bag.revealed)
        .onAppear { bag.speakMode = model.language }
        .onChange(of: model.language) { _, new in bag.speakMode = new }
    }
}

// MARK: Color

private struct WordColor: View {
    @Bindable var bag: CardBagState
    var generator: CardBagState?
    let game: Game
    let template: PlayTemplate
    var presenting: Bool
    @Environment(\.playPalette) private var pal

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            if let c = bag.current {
                VStack(spacing: 4) {
                    BiBlock(l: c.front, esSize: 64, zhSize: 44, esColor: .white, zhColor: .white.opacity(0.9), columns: template.bilingualColumns)
                    if let b = c.back { BiText(b, size: 24, align: .center, secondaryOpacity: 0.9) }
                }
                .id(bag.rollTick).transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Text("🎨").font(.system(size: 140)).opacity(0.7)
            }
            if let g = generator {
                VStack(spacing: 6) {
                    HStack(spacing: 4) { LT("CATEGORÍA", "类别") }.font(Theme.font(15, .semibold)).foregroundStyle(Theme.secondaryFixed)
                    if let c = g.current {
                        BiBlock(l: c.front, esSize: 120, zhSize: 80, esColor: Theme.inkFixed, zhColor: pal.cardAccent, columns: template.bilingualColumns)
                            .id(g.rollTick)
                    } else {
                        Text("🎲").font(.system(size: 90)).opacity(0.6)
                    }
                }
                .padding(.horizontal, 80).padding(.vertical, 34)
                .background(RoundedRectangle(cornerRadius: 36).fill(Color.white))
                .animation(.spring(duration: 0.3), value: g.rollTick)
            }
            if !presenting { controls }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.3), value: bag.rollTick)
        .onAppear {
            if bag.current == nil { bag.next() }
            if let g = generator, g.current == nil { g.next() }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if bag.manual {
                    ForEach(Array(bag.cards.enumerated()), id: \.offset) { _, card in
                        Button { bag.pick(card) } label: {
                            Circle().fill(FlashPalette.swatch(card.color)).frame(width: 44, height: 44)
                                .overlay(Circle().stroke(.white, lineWidth: bag.current == card ? 4 : 1))
                        }
                        .buttonStyle(.plain).accessibilityLabel(card.front.es)
                    }
                } else {
                    OtherButton(kind: .colorFlash) { bag.next() }
                }
                if let g = generator {
                    Button { g.next() } label: { LT("Otra categoría", "换类别") }
                        .buttonStyle(PlayButtonStyle(kind: .outline(.white), big: true))
                }
            }
            Picker("", selection: $bag.manual) {
                Text("Aleatorio · 随机").tag(false)
                Text("Manual · 手动").tag(true)
            }.pickerStyle(.segmented).fixedSize().labelsHidden()
        }
    }
}

// MARK: Boom

private struct WordBoom: View {
    @Bindable var state: BoomState
    var presenting: Bool

    var body: some View {
        WhiteCard {
            HStack {
                Spacer()
                LT("Múltiplo \(state.multiple)", "倍数 \(state.multiple)").font(Theme.font(14)).foregroundStyle(Theme.secondaryFixed)
            }
        } center: {
            if state.isBoom {
                VStack(spacing: 0) {
                    Text("💥").font(.system(size: 120))
                    Text("¡BOOM!").font(Theme.font(160, .bold)).foregroundStyle(Color(hex: 0xC92A2A))
                        .minimumScaleFactor(0.4).lineLimit(1)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(state.n)").font(Theme.font(300, .bold)).monospacedDigit().minimumScaleFactor(0.3).lineLimit(1)
            }
        } bottom: {
            if !presenting {
                HStack(spacing: 16) {
                    OtherButton(kind: .boom) { state.primary() }
                    Button { state.reset() } label: { Label { LT("Reiniciar", "重置") } icon: { Image(systemName: "arrow.counterclockwise") } }
                        .buttonStyle(PlayButtonStyle(kind: .outline(Theme.inkFixed), big: true))
                    Stepper(value: $state.multiple, in: 2...20) { LT("Múltiplo \(state.multiple)", "倍数 \(state.multiple)").font(Theme.font(15, .medium)) }.fixedSize()
                    Toggle(isOn: $state.includeDigit) { LT("Incluir dígito", "含数字") }.toggleStyle(.switch).fixedSize()
                }
            }
        }
        .animation(.spring(duration: 0.25), value: state.isBoom)
    }
}

// MARK: Código

private struct WordCode: View {
    @Bindable var state: CodeSequenceState
    var presenting: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.playPalette) private var pal

    var body: some View {
        WhiteCard {
            HStack { Spacer() }
        } center: {
            if state.sequence.isEmpty {
                Text("Pulsa «Generar» para crear una secuencia\n点击“生成”创建密码").font(Theme.font(30, .medium))
                    .multilineTextAlignment(.center).foregroundStyle(Theme.secondaryFixed)
            } else if state.hidden {
                VStack(spacing: 10) {
                    Text("🙈").font(.system(size: 120))
                    Text("Secuencia oculta · 已隐藏").font(Theme.font(34, .bold)).foregroundStyle(Theme.secondaryFixed)
                }
            } else {
                HStack(spacing: 22) {
                    ForEach(Array(state.sequence.enumerated()), id: \.offset) { _, step in
                        VStack(spacing: 8) {
                            Text(step.signal.symbol).font(.system(size: 100))
                            Text("× \(step.count)").font(Theme.font(64, .bold))
                            Text(step.signal.name.text(model.language)).font(Theme.font(20, .medium)).foregroundStyle(Theme.secondaryFixed)
                        }
                        .padding(22)
                        .background(RoundedRectangle(cornerRadius: 28).fill(Color(hex: 0xF5F3EE)))
                    }
                }
            }
        } bottom: {
            if !presenting {
                HStack(spacing: 14) {
                    OtherButton(kind: .codeSequence) { state.generate() }
                    Button { state.hidden.toggle() } label: {
                        Label { LT(state.hidden ? L("Mostrar", "显示") : L("Ocultar", "隐藏")) } icon: { Image(systemName: state.hidden ? "eye" : "eye.slash") }
                    }
                    .buttonStyle(PlayButtonStyle(kind: .outline(Theme.inkFixed), big: true))
                    .disabled(state.sequence.isEmpty)
                    Stepper(value: $state.length, in: 1...8) { LT("Longitud \(state.length)", "长度 \(state.length)").font(Theme.font(15, .medium)) }.fixedSize()
                }
            }
        }
    }
}
