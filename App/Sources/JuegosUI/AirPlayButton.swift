#if os(iOS)
import SwiftUI
import AVKit

/// Botón de AirPlay (selector de ruta de pantalla/salida) para enviar el modo juego a la tele.
/// Sustituye a la ventana «Proyector» de macOS. En iPad, al conectar por cable o AirPlay, el modo
/// juego a pantalla completa hace de proyector.
struct AirPlayButton: UIViewRepresentable {
    var tint: Color = Theme.ink
    var activeTint: Color = Theme.accentPlanificar

    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.prioritizesVideoDevices = false
        v.tintColor = UIColor(tint)
        v.activeTintColor = UIColor(activeTint)
        v.backgroundColor = .clear
        v.setContentHuggingPriority(.required, for: .horizontal)
        v.setContentHuggingPriority(.required, for: .vertical)
        return v
    }

    func updateUIView(_ v: AVRoutePickerView, context: Context) {
        v.tintColor = UIColor(tint)
        v.activeTintColor = UIColor(activeTint)
    }
}
#endif
