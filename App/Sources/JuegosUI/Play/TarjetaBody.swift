import SwiftUI
import JuegosCore

// MARK: - Plantilla Tarjeta: texto largo con cara oculta, ES | 中文, «Revelar»

struct TarjetaBody: View {
    let game: Game
    let template: PlayTemplate
    let mainIndex: Int
    var presenting: Bool

    var body: some View {
        let side = resolveSide(game: game, template: template, mainIndex: mainIndex)
        HStack(spacing: 32) {
            if side != .none && template.sidePanelLeading {
                SideColumn(game: game, side: side, presenting: presenting).frame(width: 320)
            }
            TarjetaCentral(game: game, template: template, index: mainIndex, presenting: presenting)
            if side != .none && !template.sidePanelLeading {
                SideColumn(game: game, side: side, presenting: presenting).frame(width: 320)
            }
        }
        .padding(.horizontal, 48).padding(.vertical, 28)
    }
}

private struct TarjetaCentral: View {
    @Environment(PlayController.self) private var play
    let game: Game
    let template: PlayTemplate
    let index: Int
    var presenting: Bool

    var body: some View {
        let kind = game.tools[index].kind
        switch kind {
        case .deck:
            if let b = play.bag(index) { TarjetaDeck(bag: b, game: game, template: template, presenting: presenting) }
        case .identity:
            if let b = play.bag(index) { TarjetaIdentity(bag: b, game: game, template: template, presenting: presenting) }
        case .reference:
            if let s = play.referenceState(index) {
                TarjetaReference(state: s, groups: game.tools[index].groups ?? [], template: template, presenting: presenting)
            }
        default:
            ToolBox(index: index, presenting: presenting)
        }
    }
}

private struct SegmentBar: View {
    @Environment(\.playPalette) private var pal
    let total: Int, current: Int
    var body: some View {
        if total > 1 && total <= 12 {
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule().fill(i < current ? pal.accent : pal.fg.opacity(0.18)).frame(width: 24, height: 4)
                }
            }
        }
    }
}

private struct CounterRow: View {
    @Environment(\.playPalette) private var pal
    let es: String, zh: String
    let current: Int, total: Int
    var extra: AnyView? = nil
    var body: some View {
        HStack(spacing: 12) {
            LT("\(es.uppercased()) \(current) DE \(total)", "第 \(current) / \(total) \(zh)")
                .font(Theme.font(13, .bold)).tracking(1.1).foregroundStyle(pal.accent).fixedSize()
            SegmentBar(total: total, current: current)
            if let extra { extra }
            Spacer()
        }
    }
}

// MARK: Mazo

private struct TarjetaDeck: View {
    @Environment(PlayController.self) private var play
    @Environment(\.playPalette) private var pal
    @Bindable var bag: CardBagState
    let game: Game
    let template: PlayTemplate
    var presenting: Bool

    private var k: CGFloat { presenting ? 1.3 : 1 }
    private var label: (String, String) {
        bag.groups.first.map { $0.name.es.lowercased().contains("historia") } == true ? ("Historia", "故事") : ("Pregunta", "问题")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            let total = bag.cards.count
            let pos = bag.current == nil ? 0 : max(1, bag.shown.count)
            CounterRow(es: label.0, zh: label.1, current: pos, total: total)
            if !presenting && bag.groups.count > 1 { groupPicker }
            if let c = bag.current {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        BiBlock(l: c.front, esSize: 38 * k, zhSize: 34 * k, esColor: pal.fg, zhColor: pal.fg.opacity(0.8),
                                columns: template.bilingualColumns, center: false, esWeight: .bold, zhWeight: .medium,
                                lineLimit: nil, minScale: 0.5)
                        if let b = c.back, (!template.showReveal || bag.revealed) {
                            answerBox(b)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(bag.rollTick)
                }
                .scrollIndicators(.hidden)
            } else {
                Spacer()
                Text("🃏").font(.system(size: 120)).opacity(0.5).frame(maxWidth: .infinity)
                Spacer()
            }
            Spacer(minLength: 0)
            if presenting { projectorAnswer } else { controls }
        }
        .animation(.easeInOut(duration: 0.25), value: bag.revealed)
        .animation(.easeInOut(duration: 0.25), value: bag.rollTick)
        .onAppear { if bag.current == nil, !bag.cards.isEmpty { bag.next() } }
    }

    private func answerBox(_ b: L) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LT("RESPUESTA", "答案").font(Theme.font(12, .bold)).tracking(1.1).foregroundStyle(pal.fg2)
            BiBlock(l: b, esSize: 30 * k, zhSize: 28 * k, esColor: pal.accent, zhColor: pal.fg.opacity(0.8),
                    columns: template.bilingualColumns, center: false, esWeight: .semibold, zhWeight: .medium,
                    lineLimit: nil, minScale: 0.5)
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(pal.accent.opacity(0.12)))
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var groupPicker: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(bag.groups.enumerated()), id: \.offset) { i, g in
                Button { bag.select(i); bag.next() } label: {
                    LT(g.name).font(Theme.font(14, bag.groupIndex == i ? .semibold : .regular))
                        .foregroundStyle(bag.groupIndex == i ? pal.onPrimary : pal.fg)
                        .padding(.horizontal, 14).frame(minHeight: Theme.minTap)
                        .background(Capsule().fill(bag.groupIndex == i ? pal.primary : pal.panel))
                }.buttonStyle(.plain)
            }
        }
    }

    private var projectorAnswer: some View {
        Group {
            if let a = play.answer, play.answerTick == bag.rollTick {
                LT(a.label).font(Theme.font(72, .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 22)
                    .background(RoundedRectangle(cornerRadius: 24).fill(a.color))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: play.answer)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlowLayout(spacing: 14) {
                if template.showAnswerButtons {
                    LT("Respuesta del profe:", "老师的回答：").font(Theme.font(15)).foregroundStyle(pal.fg2)
                    ForEach([AnswerChoice.yes, .no, .unrelated], id: \.rawValue) { a in
                        let selected = play.answer == a && play.answerTick == bag.rollTick
                        Button {
                            if selected { play.answer = nil } else { play.answer = a; play.answerTick = bag.rollTick }
                        } label: {
                            LT(a.label).font(Theme.font(24, .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 28).frame(minHeight: 64)
                                .background(RoundedRectangle(cornerRadius: 14).fill(a.color))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(pal.fg, lineWidth: selected ? 4 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if template.showReveal, bag.current?.back != nil, !bag.revealed {
                    Button { bag.reveal() } label: { Label { LT("Revelar la verdad", "揭晓") } icon: { Image(systemName: "eye") } }
                        .buttonStyle(PlayButtonStyle(kind: .outline(pal.accent), big: true, capsule: false, radius: 14))
                }
            }
            HStack(spacing: 12) {
                Button { bag.next() } label: { Label { LT("Siguiente", "下一张") } icon: { Image(systemName: "forward.fill") } }
                    .buttonStyle(pal.solid(big: true))
                Button { bag.shuffleAgain(); bag.next() } label: { Label { LT("Barajar", "洗牌") } icon: { Image(systemName: "shuffle") } }
                    .buttonStyle(pal.outline(big: true))
                LT("Quedan \(bag.remaining)", "剩余 \(bag.remaining)").font(Theme.font(15)).foregroundStyle(pal.fg2)
                Spacer()
            }
        }
    }
}

// MARK: Identidad

private struct TarjetaIdentity: View {
    @Environment(PlayController.self) private var play
    @Environment(AppModel.self) private var model
    @Environment(\.playPalette) private var pal
    @Bindable var bag: CardBagState
    let game: Game
    let template: PlayTemplate
    var presenting: Bool

    private var k: CGFloat { presenting ? 1.25 : 1 }
    private var hidden: Bool { play.identityHidden }

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            main
            if !presenting { aside.frame(width: 340) }
        }
        .onAppear { if bag.current == nil, !bag.cards.isEmpty { bag.next() } }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 22) {
            CounterRow(es: "Rol", zh: "角色", current: bag.current == nil ? 0 : max(1, bag.shown.count), total: bag.cards.count,
                       extra: presenting ? nil : AnyView(
                        Text(hidden ? model.t("Oculto en el proyector", "投影已隐藏") : model.t("Visible en el proyector", "投影可见"))
                            .font(Theme.font(13, .semibold))
                            .foregroundStyle(pal.isLight ? Color(hex: 0x1E40AF) : pal.fg)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(pal.accent.opacity(0.18)))))
            if presenting && hidden {
                Spacer()
                Text("🪪").font(.system(size: 160)).frame(maxWidth: .infinity).opacity(0.5)
                Spacer()
            } else if let c = bag.current {
                let fill = pal.isColored ? Color.white : game.category.color
                let ink = pal.isColored ? game.category.color : Color.white
                VStack(alignment: .leading, spacing: 4) {
                    BiBlock(l: c.front, esSize: 96 * k, zhSize: 60 * k, esColor: ink, zhColor: ink.opacity(0.9),
                            columns: false, center: false, zhWeight: .bold, lineLimit: 2, minScale: 0.4)
                }
                .padding(.horizontal, 44).padding(.vertical, 22).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 32).fill(fill))
                .id(bag.rollTick)
                if let b = c.back {
                    ScrollView {
                        HStack(alignment: .top, spacing: 40) {
                            guide(b)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                Spacer()
                Text("🪪").font(.system(size: 140)).opacity(0.5).frame(maxWidth: .infinity)
                Spacer()
            }
            Spacer(minLength: 0)
            if !presenting {
                HStack(spacing: 12) {
                    Button { bag.next() } label: { LT("Otro rol", "换一个") }.buttonStyle(pal.solid(big: true))
                    Button { play.identityHidden.toggle() } label: {
                        LT(hidden ? L("Mostrar en el proyector", "投影显示") : L("Ocultar del proyector", "投影隐藏"))
                    }
                    .buttonStyle(PlayButtonStyle(kind: .outline(pal.accent), big: true, capsule: false, radius: 14))
                    Spacer()
                }
            }
        }
        .animation(.spring(duration: 0.3), value: bag.rollTick)
    }

    @ViewBuilder private func guide(_ b: L) -> some View {
        let showES = model.language != .zh, showZH = model.language != .es && !b.zh.isEmpty
        if template.bilingualColumns && showES && showZH {
            VStack(alignment: .leading, spacing: 8) {
                Text("CÓMO TRATARLE").font(Theme.font(13, .semibold)).tracking(1.1).foregroundStyle(pal.fg2)
                Text(b.es).font(Theme.font(26 * k)).lineSpacing(6)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text("怎么对待他").font(Theme.fontZH(13, .bold)).tracking(1.1).foregroundStyle(pal.fg2)
                Text(b.zh).font(Theme.fontZH(25 * k)).lineSpacing(8).foregroundStyle(pal.fg.opacity(0.85))
            }
            .padding(.leading, 40).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) { Rectangle().fill(pal.line).frame(width: 1) }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if showES { Text(b.es.isEmpty ? b.zh : b.es).font(Theme.font(26 * k)).lineSpacing(6) }
                if showZH && showES { Text(b.zh).font(Theme.fontZH(25 * k)).lineSpacing(8).foregroundStyle(pal.fg.opacity(0.85)) }
                if !showES { Text(b.zh.isEmpty ? b.es : b.zh).font(Theme.fontZH(26 * k)).lineSpacing(8) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aside: some View {
        VStack(alignment: .leading, spacing: 14) {
            LT("ROLES", "身份").font(Theme.font(13, .semibold)).tracking(1.1).foregroundStyle(pal.fg2)
            let all = bag.cards
            let used = bag.shown.filter { $0 != bag.current }
            let rest = all.filter { c in c != bag.current && !bag.shown.contains(c) }
            FlowLayout(spacing: 6) {
                if let c = bag.current { chip(c.front, state: 0) }
                ForEach(Array(used.enumerated()), id: \.offset) { _, c in chip(c.front, state: 1) }
                ForEach(Array(rest.prefix(3).enumerated()), id: \.offset) { _, c in chip(c.front, state: 2) }
                if rest.count > 3 {
                    Text("+ \(rest.count - 3) más").font(Theme.font(14)).foregroundStyle(pal.fg2).padding(.horizontal, 4)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 10) {
                Rectangle().fill(pal.line).frame(height: 1)
                LT("PARA ANTES DE CLASE", "课前准备").font(Theme.font(13, .semibold)).tracking(1.1).foregroundStyle(pal.fg2)
                IdentityPrintButton(cards: bag.groups.flatMap(\.cards)) {
                    Label { LT("Imprimir las \(bag.groups.flatMap(\.cards).count) tarjetas", "打印") } icon: { Image(systemName: "printer") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlayButtonStyle(kind: .outline(pal.fg), capsule: false, radius: 12))
            }
        }
        .padding(22).frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 24).fill(pal.panel))
    }

    private func chip(_ l: L, state: Int) -> some View {
        let text = model.language == .zh ? l.text(.zh) : l.text(.es)
        return Text(text).font(Theme.font(14, state == 0 ? .semibold : .regular))
            .strikethrough(state == 1)
            .lineLimit(2).multilineTextAlignment(.leading)
            .frame(maxWidth: 290, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(state == 0 ? Color.white : (state == 1 ? pal.fg2 : pal.fg))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(state == 0 ? pal.accent : (pal.isLight ? Color.white : pal.fg.opacity(0.08))))
    }
}

// MARK: Referencia (etapas)

private struct TarjetaReference: View {
    @Bindable var state: ReferenceState
    let groups: [CardGroup]
    let template: PlayTemplate
    var presenting: Bool
    @Environment(\.playPalette) private var pal

    var body: some View {
        let idx = groups.indices.contains(state.groupIndex) ? state.groupIndex : 0
        VStack(alignment: .leading, spacing: 20) {
            if groups.isEmpty { EmptyCards() } else {
                HStack(spacing: 12) {
                    LT(groups[idx].name).font(Theme.font(13, .bold)).tracking(1.1).foregroundStyle(pal.accent)
                    if groups.count > 1 && !presenting {
                        Picker("", selection: $state.groupIndex) {
                            ForEach(Array(groups.enumerated()), id: \.offset) { i, g in Text(g.name.es).tag(i) }
                        }.pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                    Spacer()
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                        ForEach(Array(groups[idx].cards.enumerated()), id: \.offset) { i, c in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 14) {
                                    Text("\(i + 1)").font(Theme.font(22, .bold)).foregroundStyle(pal.isLight ? .white : pal.bg)
                                        .frame(width: 44, height: 44).background(Circle().fill(pal.accent))
                                    BiBlock(l: c.front, esSize: 32, zhSize: 26, esColor: pal.fg, zhColor: pal.fg.opacity(0.75),
                                            columns: false, center: false, lineLimit: 2)
                                }
                                if let b = c.back {
                                    BiText(b, size: 21).foregroundStyle(pal.fg.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 24).fill(pal.panel))
                        }
                    }
                    .padding(2)
                }
            }
        }
    }
}
