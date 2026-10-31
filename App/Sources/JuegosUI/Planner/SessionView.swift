import SwiftUI
import JuegosCore

// MARK: - Sesión del día (diseno/01, columna central)

struct SessionView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayController.self) private var play
    @Environment(\.colorScheme) private var scheme
    @State private var dropTargeted = false

    private static let rowGap: CGFloat = 6

    private func rowHeight(_ minutes: Int) -> CGFloat { min(168, max(56, 32 + CGFloat(minutes) * 4.8)) }

    var body: some View {
        @Bindable var model = model
        let s = model.session
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    summaryCard(s)
                    sessionBlock(s)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.t("Notas", "备注")).font(Theme.font(12, .semibold)).foregroundStyle(Theme.secondary)
                        TextEditor(text: $model.userData.currentSession.notes)
                            .font(Theme.font(14)).frame(minHeight: 70).scrollContentBackground(.hidden)
                            .padding(6).background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    }
                    historySection
                }
                .padding(20)
            }
            Button { play.startSession(model: model) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text(model.t("Empezar sesión", "开始课程")).font(Theme.font(20, .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.accentPlanificar))
                .opacity(s.items.isEmpty ? 0.4 : 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(s.items.isEmpty)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .accessibilityLabel("\(model.t("Empezar sesión", "开始课程"))")
        }
        .background(Theme.background)
        .navigationTitle(model.t("Sesión del día", "今日课程"))
    }

    // MARK: Cabecera

    private var header: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 4) {
            Text(headerDate).font(Theme.font(13, .semibold)).tracking(0.5).foregroundStyle(Theme.secondary)
            TextField(model.t("Sesión de hoy", "今日课程"), text: $model.userData.currentSession.title)
                .textFieldStyle(.plain).font(Theme.font(30, .bold)).foregroundStyle(Theme.ink)
                .accessibilityLabel(model.t("Título de la sesión", "课程标题"))
            HStack(spacing: 12) {
                DatePicker("", selection: $model.userData.currentSession.date, displayedComponents: .date).labelsHidden()
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    stepButton("minus", label: model.t("Menos tiempo disponible", "减少可用时间")) {
                        model.userData.currentSession.availableMinutes = max(5, model.session.availableMinutes - 5)
                    }
                    Text("\(model.t("Disponible", "可用")): \(model.session.availableMinutes) min")
                        .font(Theme.font(13, .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                    stepButton("plus", label: model.t("Más tiempo disponible", "增加可用时间")) {
                        model.userData.currentSession.availableMinutes = min(180, model.session.availableMinutes + 5)
                    }
                }
            }
        }
    }

    private var headerDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.setLocalizedDateFormatFromTemplate("EEEEdMMM")
        let es = f.string(from: model.session.date).uppercased()
        return model.language == .es ? es : "\(es) · 今日课程"
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.ink)
                .frame(width: Theme.minTap, height: Theme.minTap).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
    }

    // MARK: Resumen

    private func summaryCard(_ s: Session) -> some View {
        let over = s.overBudget
        let diff = abs(s.availableMinutes - s.totalMinutes)
        let denom = Double(max(1, max(s.availableMinutes, s.totalMinutes)))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                (Text("\(s.totalMinutes) ").font(Theme.font(26, .bold)).foregroundColor(Theme.ink)
                 + Text("/ \(s.availableMinutes) min").font(Theme.font(16, .medium)).foregroundColor(Theme.secondary))
                Spacer()
                Text(over ? model.t("Te pasas \(diff) min", "超时 \(diff) 分钟") : model.t("Quedan \(diff) min", "还剩 \(diff) 分钟"))
                    .font(Theme.font(14, .semibold)).foregroundStyle(over ? Theme.danger : Theme.ok)
            }
            GeometryReader { geo in
                let gaps = CGFloat(max(0, s.items.count - 1)) * 2
                let usable = geo.size.width - gaps
                HStack(spacing: 2) {
                    ForEach(s.items) { it in
                        if let g = model.game(it.gameID) {
                            Rectangle().fill(g.category.color)
                                .frame(width: max(3, usable * CGFloat(Double(it.minutes) / denom)))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, alignment: .leading)
                .background(Theme.chipNeutral)
                .clipShape(Capsule())
            }
            .frame(height: 14)
            .accessibilityHidden(true)
            Text(mixText(s)).font(Theme.font(13)).foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
        .accessibilityElement(children: .combine)
    }

    private func mixText(_ s: Session) -> String {
        var counts: [GameCategory: Int] = [:]
        for it in s.items { if let g = model.game(it.gameID) { counts[g.category, default: 0] += 1 } }
        guard !counts.isEmpty else { return "\(model.t("Mezcla", "搭配")): —" }
        let parts = GameCategory.allCases.compactMap { c -> String? in
            guard let n = counts[c] else { return nil }
            return "\(c.emoji) \(model.text(c.name).replacingOccurrences(of: "\n", with: " ")) \(n)"
        }
        return "\(model.t("Mezcla", "搭配")): " + parts.joined(separator: " · ")
    }

    // MARK: Lista

    private func sessionBlock(_ s: Session) -> some View {
        @Bindable var model = model
        let free = s.availableMinutes - s.totalMinutes
        let listHeight = s.items.reduce(CGFloat(0)) { $0 + rowHeight($1.minutes) + Self.rowGap }
        return VStack(spacing: 8) {
            if !s.items.isEmpty {
                List {
                    ForEach($model.userData.currentSession.items) { $item in
                        sessionRow($item)
                            .listRowInsets(EdgeInsets(top: Self.rowGap / 2, leading: 0, bottom: Self.rowGap / 2, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onMove { model.userData.currentSession.items.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { model.userData.currentSession.items.remove(atOffsets: $0) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: listHeight + 4)
            }
            freeBlock(free: free, empty: s.items.isEmpty)
        }
        .dropDestination(for: String.self) { ids, _ in
            for id in ids { model.addToSession(id: id) }
            return !ids.isEmpty
        } isTargeted: { dropTargeted = $0 }
    }

    @ViewBuilder
    private func sessionRow(_ item: Binding<SessionItem>) -> some View {
        let it = item.wrappedValue
        let index = (model.session.items.firstIndex { $0.id == it.id } ?? 0) + 1
        if let g = model.game(it.gameID) {
            HStack(spacing: 8) {
                Text("\(index)").font(Theme.font(13)).foregroundStyle(Theme.secondary).frame(width: 16)
                Text(g.icon).font(.system(size: 22))
                BiText(g.title, size: 14, weight: .semibold)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 0) {
                    stepButton("minus", label: "\(model.t("Menos minutos", "减少分钟")): \(g.title.es)") {
                        item.wrappedValue.minutes = max(1, item.wrappedValue.minutes - 1)
                    }
                    Text("\(it.minutes) min").font(Theme.font(14, .semibold))
                        .foregroundStyle(categoryInk(g.category, scheme)).lineLimit(1).fixedSize()
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(g.category.adaptiveTint))
                    stepButton("plus", label: "\(model.t("Más minutos", "增加分钟")): \(g.title.es)") {
                        item.wrappedValue.minutes = min(90, item.wrappedValue.minutes + 1)
                    }
                }
                .layoutPriority(1)
                Button { model.userData.currentSession.items.removeAll { $0.id == it.id } } label: {
                    Image(systemName: "trash").foregroundStyle(Theme.secondary)
                        .frame(width: Theme.minTap, height: Theme.minTap).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(model.t("Quitar de la sesión", "移出课程")): \(g.title.es)")
            }
            .padding(.leading, 12).padding(.trailing, 2)
            .frame(height: rowHeight(it.minutes))
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
            .overlay(alignment: .leading) {
                Capsule().fill(g.category.color).frame(width: 4).padding(.vertical, 10).padding(.leading, 2)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.selectedGameID = g.id }
            .contextMenu {
                Button(model.t("Subir", "上移")) { move(it.id, by: -1) }.disabled(index == 1)
                Button(model.t("Bajar", "下移")) { move(it.id, by: 1) }.disabled(index == model.session.items.count)
                Button(model.t("Quitar", "移除"), role: .destructive) { model.userData.currentSession.items.removeAll { $0.id == it.id } }
            }
        } else {
            Text("?").foregroundStyle(Theme.secondary)
        }
    }

    private func move(_ id: UUID, by d: Int) {
        var items = model.session.items
        guard let i = items.firstIndex(where: { $0.id == id }), items.indices.contains(i + d) else { return }
        items.swapAt(i, i + d)
        model.userData.currentSession.items = items
    }

    private func freeBlock(free: Int, empty: Bool) -> some View {
        let text: String
        if empty { text = model.t("\(max(0, free)) min libres · arrastra un juego aquí o pulsa +", "\(max(0, free)) 分钟空闲 · 拖入游戏或点 +") }
        else if free > 0 { text = model.t("\(free) min libres · arrastra un juego aquí", "\(free) 分钟空闲 · 拖入游戏") }
        else { text = model.t("Arrastra un juego aquí para añadirlo", "拖入游戏以添加") }
        return Text(text)
            .font(Theme.font(14)).foregroundStyle(Theme.secondary).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: empty ? 96 : 64)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 14).fill(dropTargeted ? Theme.accentPlanificar.opacity(0.12) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(dropTargeted ? Theme.accentPlanificar : Color(light: 0xD6D0C3, dark: 0x3A3A48), style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
    }

    // MARK: Historial

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.t("Historial", "历史")).font(Theme.font(17, .semibold)).foregroundStyle(Theme.ink).padding(.top, 8)
            if model.userData.history.isEmpty {
                Text(model.t("Aún no hay sesiones", "暂无记录")).font(Theme.font(14)).foregroundStyle(Theme.secondary)
            }
            ForEach(model.userData.history.prefix(10)) { h in
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(h.date.formatted(date: .abbreviated, time: .omitted))\(h.title.isEmpty ? "" : " · \(h.title)")")
                            .font(Theme.font(14, .semibold)).foregroundStyle(Theme.ink)
                        Text(h.items.compactMap { model.game($0.gameID)?.icon }.joined(separator: " ") + "  · \(h.totalMinutes) min")
                            .font(Theme.font(12)).foregroundStyle(Theme.secondary)
                        if !h.notes.isEmpty {
                            Text(h.notes).font(Theme.font(12)).foregroundStyle(Theme.secondary).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    Button(model.t("Repetir", "重复")) { model.repeatSession(h) }
                        .buttonStyle(PillButtonStyle(color: Theme.accentPlanificar, filled: false))
                    Button { model.deleteHistory(h.id) } label: {
                        Image(systemName: "trash").foregroundStyle(Theme.secondary)
                            .frame(width: Theme.minTap, height: Theme.minTap).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel(model.t("Borrar del historial", "从历史删除"))
                }
                .padding(.leading, 12).padding(.trailing, 2).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
            }
        }
    }
}
