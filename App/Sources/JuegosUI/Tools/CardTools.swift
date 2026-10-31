import SwiftUI
import UniformTypeIdentifiers
import JuegosCore

// MARK: - Selector de grupo

struct GroupChips: View {
    var state: CardBagState
    var body: some View {
        if state.groups.count > 1 {
            // FlowLayout: con muchos grupos (p. ej. 11 categorías) pasa a varias filas en vez de salirse.
            FlowLayout(spacing: 8) {
                if state.hasAllOption {
                    chip(L("Todos", "全部"), selected: state.groupIndex < 0) { state.select(-1) }
                }
                ForEach(Array(state.groups.enumerated()), id: \.offset) { i, g in
                    chip(g.name, selected: state.groupIndex == i) { state.select(i) }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func chip(_ l: L, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { ChipLabel(l: l) }
            .buttonStyle(PillButtonStyle(color: selected ? .accentColor : .white, filled: selected))
    }
}

private struct ChipLabel: View {
    @Environment(AppModel.self) private var model
    let l: L
    var body: some View { Text(l.text(model.language == .both ? .es : model.language) + (model.language == .both && !l.zh.isEmpty && l.zh != l.es ? " · \(l.zh)" : "")) }
}

struct EmptyCards: View {
    var body: some View {
        Text("Sin tarjetas · 没有卡片").font(bigFont(30, .medium)).opacity(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BigCard: View {
    var front: L
    var back: L?
    var revealed: Bool
    var tint: Color = .white
    var body: some View {
        VStack(spacing: 28) {
            BiText(front, size: 60, weight: .heavy, align: .center)
                .minimumScaleFactor(0.4)
            if revealed, let back {
                Divider().overlay(.white.opacity(0.4)).padding(.horizontal, 60)
                BiText(back, size: 40, weight: .semibold, align: .center)
                    .foregroundStyle(.yellow)
                    .minimumScaleFactor(0.4)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 36).fill(tint.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 36).stroke(tint.opacity(0.35), lineWidth: 2))
    }
}

// MARK: - Mazo

struct DeckToolView: View {
    var state: CardBagState
    var presenting: Bool

    var body: some View {
        VStack(spacing: 18) {
            if !presenting { GroupChips(state: state) }
            if state.cards.isEmpty { EmptyCards() }
            else {
                ZStack {
                    if let c = state.current {
                        BigCard(front: c.front, back: c.back, revealed: state.revealed)
                            .id(state.rollTick)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    } else {
                        Text("🃏").font(.system(size: 140)).opacity(0.5)
                    }
                }
                .animation(.spring(duration: 0.35), value: state.rollTick)
                .animation(.easeInOut, value: state.revealed)

                HStack(spacing: 16) {
                    if !presenting {
                        if state.current?.back != nil, !state.revealed {
                            Button { state.reveal() } label: { Label("Revelar respuesta · 揭晓", systemImage: "eye") }
                                .buttonStyle(PillButtonStyle(color: .orange, big: true))
                        }
                        Button { state.next() } label: { Label("Siguiente · 下一张", systemImage: "forward.fill") }
                            .buttonStyle(PillButtonStyle(color: .green, big: true))
                        Button { state.shuffleAgain() } label: { Label("Barajar · 洗牌", systemImage: "shuffle") }
                            .buttonStyle(PillButtonStyle(color: .white, filled: false))
                    }
                    Text("Quedan · 剩余 \(state.remaining)").font(bigFont(18, .medium)).opacity(0.6)
                    if state.reshuffled { Text("🔀").font(.title) }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
    }
}

// MARK: - Generador

struct GeneratorToolView: View {
    var state: CardBagState
    var presenting: Bool

    var body: some View {
        VStack(spacing: 22) {
            if !presenting { GroupChips(state: state) }
            if state.cards.isEmpty { EmptyCards() }
            else {
                ZStack {
                    if let c = state.current {
                        VStack(spacing: 18) {
                            BiText(c.front, size: 90, weight: .heavy, align: .center).minimumScaleFactor(0.3)
                            if let b = c.back {
                                BiText(b, size: 34, weight: .medium, align: .center).opacity(0.8)
                            }
                        }
                        .padding(40)
                        .id(state.rollTick)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        Text("🎲").font(.system(size: 180)).opacity(0.6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 36).fill(.white.opacity(0.07)))
                .animation(.spring(duration: 0.3), value: state.rollTick)

                if !presenting {
                    HStack(spacing: 16) {
                        Button { state.next() } label: { Label("🎲 Sortear · 随机", systemImage: "dice") }
                            .buttonStyle(PillButtonStyle(color: .pink, big: true))
                        Text("Quedan · 剩余 \(state.remaining)").font(bigFont(18, .medium)).opacity(0.6)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
    }
}

// MARK: - Referencia

struct ReferenceToolView: View {
    var cards: ReferenceState
    var groups: [CardGroup]
    var presenting: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            if groups.count > 1 && !presenting {
                Picker("", selection: Bindable(cards).groupIndex) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { i, g in Text(g.name.text(.es)).tag(i) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            let idx = groups.indices.contains(cards.groupIndex) ? cards.groupIndex : 0
            if groups.isEmpty { EmptyCards() } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                        ForEach(Array(groups[idx].cards.enumerated()), id: \.offset) { i, c in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    Text("\(i + 1)").font(bigFont(22, .heavy)).frame(width: 40, height: 40)
                                        .background(Circle().fill(Color.accentColor))
                                    BiText(c.front, size: 30, weight: .bold)
                                }
                                if let b = c.back { BiText(b, size: 22).foregroundStyle(.yellow.opacity(0.9)).fixedSize(horizontal: false, vertical: true) }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 24).fill(.white.opacity(0.1)))
                        }
                    }
                    .padding(4)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
    }
}

// MARK: - Llamador

struct CallerToolView: View {
    @Bindable var state: CardBagState
    var presenting: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 20) {
            if !presenting { GroupChips(state: state) }
            if state.cards.isEmpty { EmptyCards() } else {
                ZStack {
                    if let c = state.current {
                        VStack(spacing: 26) {
                            BiText(c.front, size: 110, weight: .black, align: .center).minimumScaleFactor(0.3)
                            if state.revealed, let b = c.back {
                                BiText(b, size: 44, weight: .semibold, align: .center).foregroundStyle(.yellow)
                            }
                        }
                        .padding(40)
                        .id(state.rollTick)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    } else {
                        Text("📣").font(.system(size: 160)).opacity(0.6)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 36).fill(.white.opacity(0.07)))
                .animation(.spring(duration: 0.3), value: state.rollTick)
                .animation(.easeInOut, value: state.revealed)

                if !presenting {
                    HStack(spacing: 16) {
                        Button { state.next() } label: { Label("Siguiente orden · 下一个口令", systemImage: "forward.fill") }
                            .buttonStyle(PillButtonStyle(color: .green, big: true))
                        if state.current?.back != nil {
                            Button { state.revealed.toggle() } label: { Label(state.revealed ? "Ocultar acción" : "Revelar acción · 揭晓", systemImage: "eye") }
                                .buttonStyle(PillButtonStyle(color: .orange, big: true))
                        }
                    }
                    HStack(spacing: 22) {
                        Toggle("Auto · 自动", isOn: Binding(get: { state.auto }, set: { state.setAuto($0) })).toggleStyle(.switch).fixedSize()
                        Stepper(value: Binding(get: { state.interval }, set: { state.setInterval($0) }), in: 1...60) {
                            Text("cada \(state.interval) s · 每\(state.interval)秒").font(bigFont(16, .medium))
                        }.fixedSize()
                        Toggle("Voz · 语音", isOn: $state.speak).toggleStyle(.switch).fixedSize()
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .onAppear { state.speakMode = model.language }
        .onChange(of: model.language) { _, new in state.speakMode = new }
    }
}

// MARK: - Color

struct ColorFlashToolView: View {
    @Bindable var state: CardBagState
    var presenting: Bool

    var body: some View {
        VStack(spacing: 14) {
            let c = state.current
            RoundedRectangle(cornerRadius: 36)
                .fill(c == nil ? Color.white.opacity(0.1) : Color.flash(c?.color))
                .overlay {
                    if let c {
                        VStack(spacing: 16) {
                            BiText(c.front, size: 100, weight: .black, align: .center).minimumScaleFactor(0.3)
                            if let b = c.back { BiText(b, size: 40, weight: .semibold, align: .center).minimumScaleFactor(0.5) }
                        }
                        .foregroundStyle(c.color == "yellow" ? Color.black : Color.white)
                        .padding(40)
                    } else {
                        Text("🎨").font(.system(size: 160)).opacity(0.7)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: state.rollTick)
            if !presenting {
                HStack(spacing: 14) {
                    Picker("", selection: $state.manual) {
                        Text("Aleatorio · 随机").tag(false)
                        Text("Manual · 手动").tag(true)
                    }.pickerStyle(.segmented).fixedSize().labelsHidden()
                    if state.manual {
                        ForEach(Array(state.cards.enumerated()), id: \.offset) { _, card in
                            Button { state.pick(card) } label: {
                                Circle().fill(Color.flash(card.color)).frame(width: 44, height: 44)
                                    .overlay(Circle().stroke(.white, lineWidth: state.current == card ? 4 : 1))
                            }.buttonStyle(.plain)
                        }
                    } else {
                        Button { state.next() } label: { Label("Cambiar · 换", systemImage: "dice") }
                            .buttonStyle(PillButtonStyle(color: .white, big: true, filled: false))
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
    }
}

// MARK: - Identidad

struct PDFDocumentFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct IdentityPage: View {
    var cards: [Card]
    var body: some View {
        let slots = cards + Array(repeating: Card(front: L("", "")), count: max(0, 6 - cards.count))
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { c in
                        let card = slots[r * 2 + c]
                        VStack(spacing: 10) {
                            if !card.front.es.isEmpty || !card.front.zh.isEmpty {
                                Text(card.front.es).font(.system(size: 22, weight: .heavy, design: .rounded))
                                Text(card.front.zh).font(.system(size: 20, weight: .bold))
                                if let b = card.back {
                                    Divider().padding(.horizontal, 20)
                                    Text(b.es).font(.system(size: 12))
                                    Text(b.zh).font(.system(size: 12))
                                }
                            }
                        }
                        .multilineTextAlignment(.center)
                        .padding(18)
                        .frame(width: 595 / 2, height: 842 / 3)
                        .overlay(Rectangle().stroke(style: StrokeStyle(lineWidth: 0.8, dash: [5, 4])).foregroundColor(.gray))
                    }
                }
            }
        }
        .foregroundColor(.black)
        .frame(width: 595, height: 842)
        .background(Color.white)
    }
}

struct IdentityToolView: View {
    @Bindable var state: CardBagState
    var presenting: Bool
    @State private var exporting = false
    @State private var pdf = PDFDocumentFile(data: Data())

    var body: some View {
        VStack(spacing: 18) {
            if state.showAll && !presenting {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                        ForEach(Array(state.cards.enumerated()), id: \.offset) { _, c in
                            VStack(alignment: .leading, spacing: 6) {
                                BiText(c.front, size: 20, weight: .bold)
                                if let b = c.back { BiText(b, size: 14).opacity(0.85) }
                            }
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
                        }
                    }
                }
            } else if state.cards.isEmpty { EmptyCards() }
            else {
                ZStack {
                    if let c = state.current {
                        BigCard(front: c.front, back: c.back, revealed: state.revealed, tint: .teal)
                            .id(state.rollTick)
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    } else {
                        Text("🪪").font(.system(size: 160)).opacity(0.6)
                    }
                }
                .animation(.spring(duration: 0.3), value: state.rollTick)
                .animation(.easeInOut, value: state.revealed)
            }
            if !presenting {
                HStack(spacing: 14) {
                    if !state.showAll {
                        if state.current?.back != nil, !state.revealed {
                            Button { state.reveal() } label: { Label("Ver guía · 看指引", systemImage: "eye") }
                                .buttonStyle(PillButtonStyle(color: .orange, big: true))
                        }
                        Button { state.next() } label: { Label("Rol aleatorio · 随机身份", systemImage: "dice") }
                            .buttonStyle(PillButtonStyle(color: .green, big: true))
                    }
                    Button { state.showAll.toggle() } label: { Label(state.showAll ? "Volver · 返回" : "Ver todas · 全部", systemImage: "square.grid.2x2") }
                        .buttonStyle(PillButtonStyle(color: .white, filled: false))
                    Button { export() } label: { Label("Exportar PDF · 导出", systemImage: "square.and.arrow.up") }
                        .buttonStyle(PillButtonStyle(color: .white, filled: false))
                        .disabled(state.cards.isEmpty)
                    Text("Quedan · 剩余 \(state.remaining)").font(bigFont(16, .medium)).opacity(0.6)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .fileExporter(isPresented: $exporting, document: pdf, contentType: .pdf, defaultFilename: "Tarjetas de identidad") { _ in }
    }

    @MainActor private func export() {
        guard let data = makeIdentityPDF(state.groups.flatMap(\.cards)) else { return }
        pdf = PDFDocumentFile(data: data)
        exporting = true
    }
}

/// PDF con las tarjetas de identidad (6 por página A4). Compartido por la herramienta y la plantilla Tarjeta.
@MainActor func makeIdentityPDF(_ all: [Card]) -> Data? {
    let pages = stride(from: 0, to: all.count, by: 6).map { Array(all[$0..<min($0 + 6, all.count)]) }
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
    var box = CGRect(x: 0, y: 0, width: 595, height: 842)
    guard let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
    for page in pages {
        let renderer = ImageRenderer(content: IdentityPage(cards: page))
        renderer.render { _, draw in
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
        }
    }
    ctx.closePDF()
    return data as Data
}

/// Botón «Imprimir» que exporta el PDF de tarjetas.
struct IdentityPrintButton<Label: View>: View {
    let cards: [Card]
    @ViewBuilder var label: () -> Label
    @State private var exporting = false
    @State private var pdf = PDFDocumentFile(data: Data())
    var body: some View {
        Button {
            if let d = makeIdentityPDF(cards) { pdf = PDFDocumentFile(data: d); exporting = true }
        } label: { label() }
        .disabled(cards.isEmpty)
        .fileExporter(isPresented: $exporting, document: pdf, contentType: .pdf, defaultFilename: "Tarjetas de identidad") { _ in }
    }
}
