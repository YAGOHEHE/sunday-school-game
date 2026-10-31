import SwiftUI
import JuegosCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    /// "#RRGGBB" del color (sRGB).
    func hexString() -> String {
        #if os(macOS)
        let c = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.gray
        let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
        #else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

extension SidePanel {
    @MainActor func label(_ model: AppModel) -> String {
        switch self {
        case .none: return model.s("Ninguno", "无")
        case .auto: return model.s("Automático", "自动")
        case .steps: return model.s("Pasos del juego", "游戏步骤")
        case .colorRules: return model.s("Reglas de color", "颜色规则")
        case .tool(let k): return model.text(k.label).replacingOccurrences(of: "\n", with: " · ")
        }
    }
    static var allOptions: [SidePanel] { [.none, .auto, .steps, .colorRules] + ToolKind.allCases.map { .tool($0) } }
}

/// Muestra de color de una plantilla (para listas).
struct TemplateSwatch: View {
    let template: PlayTemplate
    var width: CGFloat = 40
    var height: CGFloat = 28
    var body: some View {
        let bg: Color = {
            switch template.background {
            case .category: return GameCategory.expresion.color
            default: return template.background.color(category: .expresion)
            }
        }()
        RoundedRectangle(cornerRadius: 6).fill(bg)
            .frame(width: width, height: height)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.fieldBorder, lineWidth: 1))
            .overlay(alignment: template.sidePanelLeading ? .leading : .trailing) {
                if template.sidePanel != .none {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.28))
                        .frame(width: width * 0.22, height: height * 0.7).padding(.horizontal, 3)
                }
            }
    }
}

// MARK: - Hoja «Plantillas de juego · 游戏模板»

struct TemplatesEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID = "palabra"
    @State private var draft = PlayTemplate.palabra
    @State private var previewGameID: String?
    @State private var confirmDelete = false
    @State private var loaded = false

    private var saved: PlayTemplate? { model.allTemplates.first { $0.id == selectedID } }
    private var isBuiltin: Bool { saved?.isBuiltin ?? true }
    private var dirty: Bool { !isBuiltin && saved != draft }
    private var previewGame: Game? {
        model.games.first { $0.id == previewGameID } ?? model.games.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                sidebar.frame(width: 280)
                Divider()
                center.frame(maxWidth: .infinity)
                Divider()
                inspector.frame(width: 380)
            }
        }
        .frame(minWidth: 1040, idealWidth: 1180, minHeight: 620, idealHeight: 700)
        .background(Theme.background)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            let focus = model.templatesFocusID ?? model.templates.first?.id ?? "palabra"
            select(model.allTemplates.contains { $0.id == focus } ? focus : "palabra")
            previewGameID = model.games.first { $0.tools.contains { $0.kind == .deck } }?.id ?? model.games.first?.id
        }
        .confirmationDialog(deleteTitle, isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(model.s("Eliminar", "删除"), role: .destructive) { deleteSelected() }
            Button(model.s("Cancelar", "取消"), role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }

    // MARK: Cabecera

    private var header: some View {
        HStack(spacing: 14) {
            (Text("Plantillas de juego ").font(Theme.font(24, .bold)).foregroundColor(Theme.ink)
             + Text("游戏模板").font(Theme.fontZH(17, .medium)).foregroundColor(Theme.secondary))
            Spacer()
            Button(action: newTemplate) {
                Text(model.s("Nueva plantilla", "新建模板")).font(Theme.font(15)).foregroundStyle(Color(light: 0xFFFFFF, dark: 0x1F1D2B))
                    .padding(.horizontal, 16).frame(minHeight: Theme.minTap)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink)).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Button { dismiss() } label: {
                Text(model.s("Cerrar", "关闭")).font(Theme.font(15)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16).frame(minHeight: Theme.minTap)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.fieldBorder))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 28).padding(.vertical, 12)
        .background(Theme.surface)
    }

    // MARK: Columna izquierda

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel(model.s("INTEGRADAS · 不可修改", "INTEGRADAS · 不可修改"))
                ForEach(PlayTemplate.builtins) { t in row(t, locked: true) }
                sectionLabel(model.s("MÍAS · 我的模板", "MÍAS · 我的模板")).padding(.top, 14)
                if model.templates.isEmpty {
                    Text(model.s("Aún no tienes plantillas propias.", "还没有自定义模板。")).font(Theme.font(13)).foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 10)
                }
                ForEach(model.templates) { t in row(t, locked: false) }
                Menu {
                    ForEach(PlayTemplate.builtins) { t in
                        Button(model.text(t.name).replacingOccurrences(of: "\n", with: " · ")) { duplicate(t) }
                    }
                } label: {
                    Text(model.s("Duplicar una integrada…", "复制内置模板…")).font(Theme.font(14)).foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(light: 0xD6D0C3, dark: 0x3A3A48), style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)
                .padding(.top, 6)
            }
            .padding(20)
        }
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s).font(Theme.font(12, .semibold)).tracking(1).foregroundStyle(Theme.secondary)
    }

    private func row(_ t: PlayTemplate, locked: Bool) -> some View {
        let count = model.games(using: t.id).count
        let sel = selectedID == t.id
        return Button { select(t.id) } label: {
            HStack(spacing: 12) {
                TemplateSwatch(template: t)
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.text(t.name).replacingOccurrences(of: "\n", with: " · ")).font(Theme.font(15, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                    Text("\(count) \(model.s(count == 1 ? "juego" : "juegos", "个游戏"))").font(Theme.font(13)).foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
                if locked { Image(systemName: "lock").font(.system(size: 12)).foregroundStyle(Theme.secondary).accessibilityLabel(model.s("Bloqueada", "已锁定")) }
            }
            .padding(10).frame(minHeight: Theme.minTap)
            .background(RoundedRectangle(cornerRadius: 14).fill(sel ? Theme.surface : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(sel ? Theme.accentPlanificar : Color.clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(sel ? .isSelected : [])
    }

    // MARK: Centro

    private var center: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(model.s("Vista previa con", "预览游戏")).font(Theme.font(14)).foregroundStyle(Theme.secondary)
                Picker("", selection: Binding(get: { previewGame?.id ?? "" }, set: { previewGameID = $0 })) {
                    ForEach(model.games) { g in
                        Text("\(g.icon) \(g.title.es)").tag(g.id)
                    }
                }
                .labelsHidden().frame(width: 280)
                .accessibilityLabel(model.s("Juego de prueba", "测试游戏"))
                Spacer()
                Text(model.s("Proyector · 投影", "投影")).font(Theme.font(14)).foregroundStyle(Theme.secondary)
            }
            Group {
                if let g = previewGame {
                    TemplatePreview(game: g, template: draft)
                } else {
                    Color.clear
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(model.s("Cabecera, Reto, Sorteo y «Siguiente» se añaden siempre; no se pueden quitar.",
                         "标题栏、挑战、抽签和「下一个」始终显示，无法移除。"))
                .font(Theme.font(13)).foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 28).padding(.vertical, 24)
    }

    // MARK: Inspector

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isBuiltin {
                        Label(model.s("Integrada: no se puede modificar. Duplícala para personalizarla.", "内置模板不可修改，请复制后再编辑。"), systemImage: "lock")
                            .font(Theme.font(13)).foregroundStyle(Theme.secondary)
                    }
                    Group {
                        nameField
                        group(model.s("Disposición base", "基础布局")) {
                            segmented(PlayLayout.allCases, selection: $draft.base) { model.text($0.name).replacingOccurrences(of: "\n", with: " ") }
                        }
                        group(model.s("Fondo", "背景")) { backgroundPicker }
                        group(model.s("Zona central", "中央区域")) {
                            Picker("", selection: $draft.mainTool) {
                                Text(model.s("Herramienta principal del juego", "游戏主工具")).tag(ToolKind?.none)
                                ForEach(ToolKind.allCases, id: \.self) { k in
                                    Text(model.text(k.label).replacingOccurrences(of: "\n", with: " · ")).tag(ToolKind?.some(k))
                                }
                            }.labelsHidden()
                        }
                        HStack(alignment: .bottom, spacing: 8) {
                            group(model.s("Panel lateral", "侧面板")) {
                                Picker("", selection: $draft.sidePanel) {
                                    ForEach(SidePanel.allOptions, id: \.self) { p in Text(p.label(model)).tag(p) }
                                }.labelsHidden()
                            }
                            segmented([true, false], selection: $draft.sidePanelLeading) { $0 ? model.s("Izq.", "左") : model.s("Der.", "右") }
                                .frame(width: 120)
                                .disabled(draft.sidePanel == .none)
                                .accessibilityLabel(model.s("Posición del panel", "面板位置"))
                        }
                        group("ES + 中文") {
                            segmented([false, true], selection: $draft.bilingualColumns) { $0 ? model.s("En columnas", "分栏") : model.s("Apilado", "堆叠") }
                        }
                        VStack(spacing: 2) {
                            toggle(model.s("Botón «Revelar»", "「揭晓」按钮"), $draft.showReveal)
                            toggle(model.s("Botones Sí / No / No tiene relación", "是 / 否 / 无关 按钮"), $draft.showAnswerButtons)
                            toggle(model.s("Pasos siempre visibles", "步骤始终可见"), $draft.showSteps)
                        }
                    }
                    .disabled(isBuiltin)
                }
                .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 8)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(usedIn).font(Theme.font(13)).foregroundStyle(Theme.secondary).lineLimit(2)
                HStack(spacing: 8) {
                    if isBuiltin {
                        button(model.s("Duplicar", "复制"), filled: true) { duplicate(draft) }
                    } else {
                        button(model.s("Guardar", "保存"), filled: true) { model.saveTemplate(draft) }.disabled(!dirty)
                        button(model.s("Duplicar", "复制"), filled: false) { duplicate(draft) }
                        button(model.s("Eliminar", "删除"), filled: false, color: Theme.danger) { confirmDelete = true }
                    }
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 16)
        }
        .background(Theme.surface)
    }

    private var nameField: some View {
        group(model.s("Nombre", "名称")) {
            HStack(spacing: 8) {
                TextField("Nombre", text: $draft.name.es).textFieldStyle(.plain).font(Theme.font(15))
                    .padding(.horizontal, 10).frame(minHeight: 40).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.fieldBorder))
                    .accessibilityLabel(model.s("Nombre en español", "西班牙语名称"))
                TextField("名称", text: $draft.name.zh).textFieldStyle(.plain).font(Theme.fontZH(15))
                    .padding(.horizontal, 10).frame(width: 110, height: 40).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.fieldBorder))
                    .accessibilityLabel(model.s("Nombre en chino", "中文名称"))
            }
        }
    }

    private var backgroundPicker: some View {
        let customHex: String? = { if case .custom(let h) = draft.background { return h } else { return nil } }()
        return HStack(spacing: 8) {
            bgButton(model.s("Categoría", "分类"), fill: GameCategory.expresion.tint, ink: Theme.inkFixed, on: draft.background == .category) { draft.background = .category }
            bgButton(model.s("Oscuro", "深色"), fill: Theme.darkSurface, ink: .white, on: draft.background == .dark) { draft.background = .dark }
            bgButton(model.s("Claro", "浅色"), fill: .white, ink: Theme.inkFixed, on: draft.background == .light) { draft.background = .light }
            bgButton(model.s("Color…", "颜色…"), fill: customHex.flatMap { Color(hexString: $0) } ?? .white, ink: customHex == nil ? Theme.inkFixed : .white,
                     on: customHex != nil) { draft.background = .custom(hex: customHex ?? "#6D3FD0") }
            if let hex = customHex {
                ColorPicker("", selection: Binding(get: { Color(hexString: hex) ?? .gray }, set: { draft.background = .custom(hex: $0.hexString()) }), supportsOpacity: false)
                    .labelsHidden().accessibilityLabel(model.s("Elegir color de fondo", "选择背景颜色"))
            }
        }
    }

    private func bgButton(_ title: String, fill: Color, ink: Color, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.font(13)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: Theme.minTap)
                .background(RoundedRectangle(cornerRadius: 10).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Theme.accentPlanificar : Theme.fieldBorder, lineWidth: on ? 2 : 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Theme.font(13, .semibold)).foregroundStyle(Theme.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segmented<V: Hashable>(_ options: [V], selection: Binding<V>, label: @escaping (V) -> String) -> some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { o in
                let on = selection.wrappedValue == o
                Button { selection.wrappedValue = o } label: {
                    Text(label(o)).font(Theme.font(14, on ? .semibold : .regular)).foregroundStyle(on ? Theme.ink : Theme.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(RoundedRectangle(cornerRadius: 9).fill(on ? Theme.surface : Color.clear)
                            .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 1, y: 1))
                        .frame(minHeight: Theme.minTap).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.chipNeutral))
    }

    private func toggle(_ title: String, _ b: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(Theme.font(15)).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Toggle("", isOn: b).labelsHidden().toggleStyle(.switch).tint(Theme.accentPlanificar)
        }
        .frame(minHeight: Theme.minTap)
        .accessibilityElement(children: .combine)
    }

    private func button(_ title: String, filled: Bool, color: Color = Theme.accentPlanificar, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.font(15, filled ? .semibold : .regular)).foregroundStyle(filled ? .white : color)
                .padding(.horizontal, 16).frame(maxWidth: filled ? .infinity : nil, minHeight: Theme.minTap)
                .background(RoundedRectangle(cornerRadius: 12).fill(filled ? color : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(filled ? Color.clear : Theme.fieldBorder))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Lógica

    private var usedIn: String {
        let names = model.games(using: selectedID).map { model.text($0.title).replacingOccurrences(of: "\n", with: " ") }
        if names.isEmpty { return model.s("Usada en: ningún juego", "使用于：暂无游戏") }
        let shown = names.prefix(4).joined(separator: ", ")
        return "\(model.s("Usada en", "使用于")): \(shown)\(names.count > 4 ? " +\(names.count - 4)" : "")"
    }

    private var deleteTitle: String { model.s("¿Eliminar la plantilla «\(saved?.name.es ?? "")»?", "删除模板「\(saved?.name.zh ?? "")」？") }
    private var deleteMessage: String {
        let n = model.customGamesExplicitlyUsing(selectedID)
        if n == 0 { return model.s("Ningún juego la usa.", "没有游戏使用它。") }
        return model.s("La usan \(n) juego(s); volverán a «Automática».", "有 \(n) 个游戏使用它，将恢复为「自动」。")
    }

    private func select(_ id: String) {
        selectedID = id
        if let t = model.allTemplates.first(where: { $0.id == id }) { draft = t }
    }

    private func newTemplate() {
        var t = PlayTemplate.tarjeta
        t.id = "tpl-" + UUID().uuidString.prefix(8).lowercased()
        t.name = L("Nueva plantilla", "新模板")
        model.saveTemplate(t)
        select(t.id)
    }

    private func duplicate(_ t: PlayTemplate) {
        let c = model.duplicate(t)
        select(c.id)
    }

    private func deleteSelected() {
        model.deleteTemplate(id: selectedID)
        select(model.templates.first?.id ?? "palabra")
    }
}
