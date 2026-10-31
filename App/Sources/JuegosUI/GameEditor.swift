import SwiftUI
import JuegosCore

private struct GroupDraft: Identifiable {
    var id = UUID()
    var nameES = ""
    var nameZH = ""
    var text = ""   // frente es | frente zh | reverso es | reverso zh | color
}

private struct ToolDraft: Identifiable {
    var id = UUID()
    var kind: ToolKind
    var title: L?
    var seconds = 300
    var teams = 2
    var multiple = 7
    var length = 4
    var groups: [GroupDraft] = []

    static let groupKinds: Set<ToolKind> = [.deck, .generator, .reference, .caller, .colorFlash, .identity]

    init(kind: ToolKind) { self.kind = kind }

    init(spec: ToolSpec) {
        kind = spec.kind; title = spec.title
        seconds = spec.seconds ?? 60; teams = spec.teams ?? 2; multiple = spec.multiple ?? 7; length = spec.length ?? 4
        groups = (spec.groups ?? []).map { g in
            GroupDraft(nameES: g.name.es, nameZH: g.name.zh, text: g.cards.map { c in
                var cols = [c.front.es, c.front.zh, c.back?.es ?? "", c.back?.zh ?? ""]
                if let col = c.color { cols.append(col) }
                return cols.joined(separator: " | ")
            }.joined(separator: "\n"))
        }
    }

    func spec() -> ToolSpec {
        var s = ToolSpec(kind: kind, title: title)
        switch kind {
        case .timer: s.seconds = seconds
        case .scoreboard: s.teams = teams
        case .boom: s.multiple = multiple
        case .codeSequence: s.length = length
        default: break
        }
        if Self.groupKinds.contains(kind) {
            s.groups = groups.map { g in
                let cards: [Card] = g.text.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
                    let cols = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
                    guard let f = cols.first, !(f.isEmpty && (cols.count < 2 || cols[1].isEmpty)) else { return nil }
                    let fes = f, fzh = cols.count > 1 ? cols[1] : ""
                    let bes = cols.count > 2 ? cols[2] : "", bzh = cols.count > 3 ? cols[3] : ""
                    let back: L? = (bes.isEmpty && bzh.isEmpty) ? nil : L(bes, bzh)
                    let color: String? = cols.count > 4 && !cols[4].isEmpty ? cols[4] : nil
                    return Card(front: L(fes, fzh), back: back, color: color)
                }
                return CardGroup(name: L(g.nameES, g.nameZH), cards: cards)
            }
        }
        return s
    }
}

struct GameEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let target: EditorTarget

    @State private var icon = ""
    @State private var titleES = ""
    @State private var titleZH = ""
    @State private var category: GameCategory = .energia
    @State private var minM = 5
    @State private var maxM = 10
    @State private var objES = ""
    @State private var objZH = ""
    @State private var stepsES = ""
    @State private var stepsZH = ""
    @State private var tipsES = ""
    @State private var tipsZH = ""
    @State private var tools: [ToolDraft] = []
    @State private var loaded = false

    private var g: Game { target.game }
    private var canSave: Bool { !(titleES.trimmingCharacters(in: .whitespaces).isEmpty && titleZH.trimmingCharacters(in: .whitespaces).isEmpty) }

    private enum Tab: String, CaseIterable { case ficha, herramientas, modo }
    @State private var tab: Tab = .ficha
    @State private var templateChoice: String?
    @State private var showTemplatesSheet = false

    private func tabLabel(_ t: Tab) -> String {
        switch t {
        case .ficha: return model.s("Ficha", "资料")
        case .herramientas: return model.s("Herramientas", "工具")
        case .modo: return model.s("Modo juego", "游戏模式")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(icon.isEmpty ? "🎲" : icon).font(.system(size: 26))
                Text(target.isNew ? model.t("Nuevo juego", "新游戏") : "\(model.t("Editar", "编辑")): \(g.title.es)")
                    .font(Theme.font(20, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        let on = tab == t
                        Button { tab = t } label: {
                            Text(tabLabel(t)).font(Theme.font(14, on ? .semibold : .regular))
                                .foregroundStyle(on ? Theme.ink : Theme.secondary)
                                .padding(.horizontal, 12).frame(minHeight: 34)
                                .background(RoundedRectangle(cornerRadius: 9).fill(on ? Theme.surface : Color.clear))
                                .frame(minHeight: Theme.minTap).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 4).background(RoundedRectangle(cornerRadius: 12).fill(Theme.chipNeutral))
            }
            .padding(.horizontal, 28).padding(.vertical, 12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch tab {
                    case .ficha: fichaTab
                    case .herramientas: toolsSection
                    case .modo: modoTab
                    }
                }
                .padding(.horizontal, 28).padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack(spacing: 10) {
                Spacer()
                Button { dismiss() } label: {
                    Text(model.s("Cancelar", "取消")).font(Theme.font(15)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 18).frame(minHeight: Theme.minTap)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.fieldBorder)).contentShape(Rectangle())
                }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
                Button { save() } label: {
                    Text(model.s("Guardar juego", "保存游戏")).font(Theme.font(15, .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 18).frame(minHeight: Theme.minTap)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accentPlanificar))
                        .opacity(canSave ? 1 : 0.4).contentShape(Rectangle())
                }.buttonStyle(.plain).keyboardShortcut(.defaultAction).disabled(!canSave)
            }
            .padding(.horizontal, 28).padding(.vertical, 14)
        }
        .background(Theme.surface)
        .frame(minWidth: 820, minHeight: 680)
        .onAppear(perform: load)
        .sheet(isPresented: $showTemplatesSheet) { TemplatesEditorView() }
    }

    private var fichaTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                field(model.t("Icono", "图标"), text: $icon).frame(width: 80)
                field(model.t("Título (ES)", "标题 (ES)"), text: $titleES)
                field(model.t("Título (中文)", "标题 (中文)"), text: $titleZH)
            }
            HStack(spacing: 18) {
                Picker(model.t("Categoría", "分类"), selection: $category) {
                    ForEach(GameCategory.allCases, id: \.self) { c in Text("\(c.emoji) \(c.name.es)").tag(c) }
                }.frame(width: 240)
                Stepper("\(model.t("Mín", "最少")): \(minM)", value: $minM, in: 1...90)
                Stepper("\(model.t("Máx", "最多")): \(maxM)", value: $maxM, in: 1...90)
            }
            HStack(alignment: .top, spacing: 12) {
                editor(model.t("Objetivo (ES)", "目标 (ES)"), text: $objES, height: 70)
                editor(model.t("Objetivo (中文)", "目标 (中文)"), text: $objZH, height: 70)
            }
            Text(model.t("Pasos: una línea por paso", "步骤：每行一步")).font(.caption.bold()).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                editor("ES", text: $stepsES, height: 150)
                editor("中文", text: $stepsZH, height: 150)
            }
            Text(model.t("Consejos: una línea por consejo", "小贴士：每行一条")).font(.caption.bold()).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                editor("ES", text: $tipsES, height: 90)
                editor("中文", text: $tipsZH, height: 90)
            }
            dangerZone
        }
    }

    // MARK: Modo juego (diseno/41)

    private var draftTools: [ToolSpec] { tools.map { $0.spec() } }

    private var automaticTemplate: (PlayTemplate, String) {
        var tmp = g; tmp.tools = draftTools; tmp.template = nil
        let t = resolveTemplate(for: tmp, custom: model.templates)
        let name = (model.language == .zh ? t.name.zh : t.name.es).replacingOccurrences(of: "\n", with: " · ")
        if let i = tmp.primaryToolIndex {
            let k = (model.language == .zh ? tmp.tools[i].kind.label.zh : tmp.tools[i].kind.label.es)
            return (t, model.s("\(t.name.es), porque la herramienta principal es «\(k)»", "\(t.name.zh)，因为主工具是「\(k)」"))
        }
        return (t, model.s("\(name), porque el juego no tiene herramientas", "\(name)，因为游戏没有工具"))
    }

    private var missingTools: [ToolKind] {
        guard let id = templateChoice, let t = model.allTemplates.first(where: { $0.id == id }) else { return [] }
        let have = Set(tools.map(\.kind))
        return t.requiredTools.filter { !have.contains($0) }
    }

    private var modoTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t("PLANTILLA EN EL MODO JUEGO", "游戏模式模板")).font(Theme.font(13, .semibold)).tracking(0.7).foregroundStyle(Theme.secondary)
            let auto = automaticTemplate
            optionRow(id: nil, swatch: auto.0, title: model.t("Automática", "自动"), subtitle: auto.1, mine: false)
            ForEach(PlayTemplate.builtins) { t in
                optionRow(id: t.id, swatch: t, title: model.text(t.name).replacingOccurrences(of: "\n", with: " · "), subtitle: nil, mine: false)
            }
            ForEach(model.templates) { t in
                optionRow(id: t.id, swatch: t, title: model.text(t.name).replacingOccurrences(of: "\n", with: " · "),
                          subtitle: model.t("Plantilla propia · \(t.base.name.es)", "自定义模板 · \(t.base.name.zh)"), mine: true)
            }
            HStack(spacing: 16) {
                Button { showTemplatesSheet = true } label: {
                    Text(model.t("Crear o editar plantillas…", "创建或编辑模板…")).font(Theme.font(15, .semibold)).foregroundStyle(Theme.accentPlanificar)
                        .frame(minHeight: Theme.minTap).contentShape(Rectangle())
                }.buttonStyle(.plain)
                if !missingTools.isEmpty {
                    let names = missingTools.map { model.text($0.label).replacingOccurrences(of: "\n", with: " · ") }.joined(separator: ", ")
                    Text(model.t("Esta plantilla usa \(names): se añadirá a las herramientas del juego.", "此模板使用 \(names)：将添加到游戏工具中。"))
                        .font(Theme.font(13)).foregroundStyle(GameCategory.energia.color)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(GameCategory.energia.adaptiveTint))
                }
            }
            .padding(.top, 6)
        }
    }

    private func optionRow(id: String?, swatch: PlayTemplate, title: String, subtitle: String?, mine: Bool) -> some View {
        let on = templateChoice == id
        return Button { templateChoice = id } label: {
            HStack(spacing: 14) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(size: 18))
                    .foregroundStyle(on ? Theme.accentPlanificar : Theme.secondary)
                TemplateSwatch(template: swatch, width: 56, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.font(16, .semibold)).foregroundStyle(Theme.ink)
                    if let subtitle { Text(subtitle).font(Theme.font(13)).foregroundStyle(Theme.secondary).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 0)
                if mine {
                    Text(model.t("MÍA", "我的")).font(Theme.font(12, .semibold)).foregroundStyle(Theme.accentPlanificar)
                        .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(GameCategory.mente.adaptiveTint))
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 16).fill(on ? Theme.accentPlanificar.opacity(0.08) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(on ? Theme.accentPlanificar : Theme.border, lineWidth: on ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Herramientas

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.t("Herramientas", "工具")).font(.headline)
                Spacer()
                Menu {
                    ForEach(ToolKind.allCases, id: \.self) { k in
                        Button(k.label.es + " · " + k.label.zh) { tools.append(defaultTool(k)) }
                    }
                } label: { Label(model.t("Añadir herramienta", "添加工具"), systemImage: "plus") }
                    .fixedSize()
            }
            ForEach($tools) { $t in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(t.kind.label.es + " · " + t.kind.label.zh, systemImage: t.kind.symbol).font(.subheadline.bold())
                        Spacer()
                        Button(role: .destructive) { tools.removeAll { $0.id == t.id } } label: { Image(systemName: "trash") }
                    }
                    switch t.kind {
                    case .timer: Stepper("\(model.t("Segundos", "秒")): \(t.seconds)", value: $t.seconds, in: 5...3600, step: 5)
                    case .scoreboard: Stepper("\(model.t("Equipos", "队伍")): \(t.teams)", value: $t.teams, in: 1...8)
                    case .boom: Stepper("\(model.t("Múltiplo", "倍数")): \(t.multiple)", value: $t.multiple, in: 2...20)
                    case .codeSequence: Stepper("\(model.t("Longitud", "长度")): \(t.length)", value: $t.length, in: 1...8)
                    default: EmptyView()
                    }
                    if ToolDraft.groupKinds.contains(t.kind) {
                        Text("frente es | frente zh | reverso es | reverso zh" + (t.kind == .colorFlash ? " | color" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach($t.groups) { $grp in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    TextField("Grupo (ES)", text: $grp.nameES).textFieldStyle(.roundedBorder)
                                    TextField("分组 (中文)", text: $grp.nameZH).textFieldStyle(.roundedBorder)
                                    Button(role: .destructive) { t.groups.removeAll { $0.id == grp.id } } label: { Image(systemName: "minus.circle") }
                                }
                                TextEditor(text: $grp.text).font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 100).padding(4)
                                    .background(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                            }
                        }
                        Button { t.groups.append(GroupDraft(nameES: "Grupo", nameZH: "分组")) } label: {
                            Label(model.t("Añadir grupo", "添加分组"), systemImage: "plus")
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
            }
        }
    }

    private var dangerZone: some View {
        HStack(spacing: 12) {
            if model.isOverride(g.id) {
                Button(model.t("Restaurar original", "恢复原版")) { model.deleteCustom(g.id); dismiss() }
            }
            if model.isCustom(g.id) && !model.isInCatalog(g.id) {
                Button(model.t("Eliminar", "删除"), role: .destructive) { model.deleteCustom(g.id); dismiss() }
            }
            if model.isInCatalog(g.id) {
                Button(model.t("Ocultar", "隐藏")) { model.hide(g.id); dismiss() }
            }
        }
        .padding(.top, 8)
    }

    private func defaultTool(_ k: ToolKind) -> ToolDraft {
        var d = ToolDraft(kind: k)
        if ToolDraft.groupKinds.contains(k) { d.groups = [GroupDraft(nameES: "Grupo", nameZH: "分组")] }
        return d
    }

    // MARK: UI helpers

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            TextField("", text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func editor(_ label: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            TextEditor(text: text).frame(height: height).padding(4)
                .background(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }

    // MARK: Carga / guardado

    private func load() {
        guard !loaded else { return }
        loaded = true
        icon = g.icon; titleES = g.title.es; titleZH = g.title.zh; category = g.category
        minM = g.minMinutes; maxM = g.maxMinutes
        objES = g.objective.es; objZH = g.objective.zh
        stepsES = g.steps.map(\.es).joined(separator: "\n"); stepsZH = g.steps.map(\.zh).joined(separator: "\n")
        tipsES = g.tips.map(\.es).joined(separator: "\n"); tipsZH = g.tips.map(\.zh).joined(separator: "\n")
        tools = g.tools.map(ToolDraft.init(spec:))
        templateChoice = g.template
        #if DEBUG
        if CommandLine.arguments.contains("--editor-modo") { tab = .modo }
        #endif
    }

    private func lines(_ s: String) -> [String] {
        s.split(separator: "\n", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func pair(_ es: String, _ zh: String) -> [L] {
        let a = lines(es), b = lines(zh)
        let n = max(a.count, b.count)
        return (0..<n).compactMap { i in
            let x = i < a.count ? a[i] : "", y = i < b.count ? b[i] : ""
            return (x.isEmpty && y.isEmpty) ? nil : L(x, y)
        }
    }

    private func save() {
        var out = g
        out.icon = icon.isEmpty ? "🎲" : String(icon.prefix(4))
        out.title = L(titleES, titleZH)
        out.category = category
        out.minMinutes = min(minM, maxM); out.maxMinutes = max(minM, maxM)
        out.objective = L(objES, objZH)
        out.steps = pair(stepsES, stepsZH)
        out.tips = pair(tipsES, tipsZH)
        out.tools = tools.map { $0.spec() }
        out.template = templateChoice
        if let id = templateChoice, let t = model.allTemplates.first(where: { $0.id == id }) {
            let have = Set(out.tools.map(\.kind))
            for k in t.requiredTools where !have.contains(k) {
                var d = defaultTool(k)
                if k == .timer { d.seconds = 300 }
                out.tools.append(d.spec())
            }
        } else if templateChoice != nil { out.template = nil }
        model.saveCustom(out)
        dismiss()
    }
}
