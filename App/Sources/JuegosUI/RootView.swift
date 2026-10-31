import SwiftUI
import JuegosCore

public struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayController.self) private var play
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    public init() {}

    private var languageBinding: Binding<LanguageMode> {
        Binding(get: { model.language }, set: { model.language = $0 })
    }
    private var editorBinding: Binding<EditorTarget?> {
        Binding(get: { model.editor }, set: { model.editor = $0 })
    }

    public var body: some View {
        Group {
            if play.isActive {
                PlayView()
            } else {
                NavigationSplitView {
                    LibraryView()
                        .navigationSplitViewColumnWidth(min: 280, ideal: 310, max: 400)
                } content: {
                    SessionView()
                        .navigationSplitViewColumnWidth(min: 420, ideal: 480, max: 600)
                } detail: {
                    GameDetailView()
                        .navigationSplitViewColumnWidth(min: 380, ideal: 700)
                }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Idioma", selection: languageBinding) {
                            Text("ES").tag(LanguageMode.es)
                            Text("中文").tag(LanguageMode.zh)
                            Text("ES + 中文").tag(LanguageMode.both)
                        }
                        .pickerStyle(.segmented).frame(width: 220)
                    }
                    ToolbarItemGroup {
                        HistoryButton()
                        Button { model.openTemplates() } label: { Label(model.t("Plantillas", "模板"), systemImage: "rectangle.3.group") }
                        #if os(macOS)
                        Button { openWindow(id: "projector") } label: { Label(model.t("Proyector", "投影"), systemImage: "tv") }
                        #endif
                    }
                }
            }
        }
        .sheet(item: editorBinding) { target in
            GameEditorView(target: target)
        }
        .sheet(isPresented: Binding(get: { model.showTemplates }, set: { model.showTemplates = $0 })) {
            TemplatesEditorView()
        }
        .background(Theme.background)
    }
}

/// Distribución que ajusta los elementos en varias filas según el ancho disponible (mínimo ancho = el elemento más ancho).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    private func rows(_ subviews: Subviews, width: CGFloat) -> (positions: [CGPoint], size: CGSize) {
        var pos: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            pos.append(CGPoint(x: x, y: y))
            x += s.width + spacing; rowH = max(rowH, s.height); maxX = max(maxX, x - spacing)
        }
        return (pos, CGSize(width: maxX, height: y + rowH))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        let r = rows(subviews, width: w.isFinite ? w : 100_000)
        // Con ancho propuesto finito devolvemos como mucho ese ancho para no forzar la columna.
        return CGSize(width: w.isFinite ? min(r.size.width, w) : r.size.width, height: r.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = rows(subviews, width: bounds.width)
        for (sv, p) in zip(subviews, r.positions) {
            sv.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }
}
