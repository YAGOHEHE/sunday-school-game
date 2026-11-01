import SwiftUI
import JuegosCore

public struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayController.self) private var play
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hsize
    @State private var showDetail = false
    @State private var showLibrarySheet = false
    @State private var showHistory = false
    #endif

    public init() {}

    private var languageBinding: Binding<LanguageMode> {
        Binding(get: { model.language }, set: { model.language = $0 })
    }
    private var editorBinding: Binding<EditorTarget?> {
        Binding(get: { model.editor }, set: { model.editor = $0 })
    }

    public var body: some View {
        planner
        .sheet(item: editorBinding) { target in
            GameEditorView(target: target)
        }
        .sheet(isPresented: Binding(get: { model.showTemplates }, set: { model.showTemplates = $0 })) {
            TemplatesEditorView()
        }
        .background(Theme.background)
    }

    @ViewBuilder private var planner: some View {
        if play.isActive {
            PlayView()
        } else {
            #if os(macOS)
            macPlanner
            #else
            iPadPlanner
            #endif
        }
    }

    // MARK: - macOS

    #if os(macOS)
    private var macPlanner: some View {
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
                Button { openWindow(id: "projector") } label: { Label(model.t("Proyector", "投影"), systemImage: "tv") }
            }
        }
    }
    #endif

    // MARK: - iPadOS

    #if os(iOS)
    private var iPadPlanner: some View {
        GeometryReader { geo in
            // En iPad a pantalla completa el size class es siempre .regular: decidir también por orientación.
            let useCompact = hsize == .compact || geo.size.height > geo.size.width
            Group { if useCompact { compactPlanner } else { regularPlanner } }
                .onChange(of: model.selectedGameID) { _, id in if id != nil { showDetail = true } }
                .sheet(isPresented: $showHistory) { HistoryView() }
                #if DEBUG
                .task {
                    // Solo depuración: JUEGOS_SHOW=lib|detail abre la hoja de biblioteca o la ficha.
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    switch ProcessInfo.processInfo.environment["JUEGOS_SHOW"] {
                    case "lib": showLibrarySheet = true
                    case "detail": showDetail = true
                    default: break
                    }
                }
                #endif
        }
    }

    /// Horizontal: biblioteca + sesión en NavigationSplitView; la ficha en un inspector deslizante.
    private var regularPlanner: some View {
        ZStack(alignment: .trailing) {
            NavigationSplitView {
                LibraryView()
                    .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
                    .toolbar(removing: .sidebarToggle)
            } detail: {
                NavigationStack {
                    SessionView()
                        .toolbar { iosToolbar(regular: true) }
                        .toolbarTitleDisplayMode(.inline)
                        .overlay(alignment: .bottomTrailing) { if !showDetail { startFab } }
                }
            }
            .navigationSplitViewStyle(.balanced)

            if showDetail {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button { showDetail = false } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                                .frame(width: Theme.minTap, height: Theme.minTap)
                                .background(Circle().fill(Theme.background))
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(model.t("Cerrar ficha", "关闭"))
                    }
                    .padding(.horizontal, 12).padding(.top, 8)
                    GameDetailView()
                }
                .frame(width: 440)
                .frame(maxHeight: .infinity)
                .background(Theme.surface)
                    .shadow(color: .black.opacity(0.14), radius: 24, x: -12)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .animation(.spring(duration: 0.3), value: showDetail)
    }

    /// Vertical: sesión a pantalla completa; biblioteca y ficha como hojas.
    private var compactPlanner: some View {
        NavigationStack {
            SessionView()
                .toolbar { iosToolbar(regular: false) }
                .toolbarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showLibrarySheet) {
            NavigationStack {
                LibraryView()
                    .navigationTitle(model.t("Biblioteca", "游戏库"))
                    .toolbarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(model.s("Listo", "完成")) { showLibrarySheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                GameDetailView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(model.s("Listo", "完成")) { showDetail = false }
                        }
                    }
            }
        }
        .overlay(alignment: .bottomLeading) { libraryFab }
        .overlay(alignment: .bottomTrailing) { startFab }
    }

    @ToolbarContentBuilder private func iosToolbar(regular: Bool) -> some ToolbarContent {
        if regular {
            ToolbarItem(placement: .principal) {
                Picker("Idioma", selection: languageBinding) {
                    Text("ES").tag(LanguageMode.es)
                    Text("中文").tag(LanguageMode.zh)
                    Text("ES + 中文").tag(LanguageMode.both)
                }
                .pickerStyle(.segmented).frame(width: 240)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            AirPlayButton().frame(width: 32, height: 32)
                .accessibilityLabel(model.t("Enviar a la tele con AirPlay", "用 AirPlay 投屏"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if !regular {
                    Picker(model.t("Idioma", "语言"), selection: languageBinding) {
                        Text("Español").tag(LanguageMode.es)
                        Text("中文").tag(LanguageMode.zh)
                        Text("ES + 中文").tag(LanguageMode.both)
                    }
                    Divider()
                }
                Button { showHistory = true } label: { Label(model.t("Historial", "历史"), systemImage: "clock.arrow.circlepath") }
                Button { model.openTemplates() } label: { Label(model.t("Plantillas", "模板"), systemImage: "rectangle.3.group") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel(model.t("Plantillas e historial", "模板和历史"))
        }
    }

    private var startFab: some View {
        Button { play.startSession(model: model) } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                Text(model.t("Empezar", "开始")).font(Theme.font(20, .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28).frame(minHeight: 64)
            .background(Capsule().fill(Theme.accentPlanificar))
            .shadow(color: Theme.accentPlanificar.opacity(0.35), radius: 12, y: 6)
            .opacity(model.session.items.isEmpty ? 0.4 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(model.session.items.isEmpty)
        .padding(.trailing, 28).padding(.bottom, 26)
        .accessibilityLabel(model.t("Empezar sesión", "开始课程"))
    }

    private var libraryFab: some View {
        Button { showLibrarySheet = true } label: {
            HStack(spacing: 10) {
                Text("＋").font(Theme.font(26, .semibold))
                Text(model.t("Biblioteca", "游戏库")).font(Theme.font(18, .semibold))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 24).frame(minHeight: 64)
            .background(Capsule().fill(Theme.surface))
            .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.leading, 26).padding(.bottom, 26)
        .accessibilityLabel(model.t("Abrir la biblioteca de juegos", "打开游戏库"))
    }
    #endif
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
