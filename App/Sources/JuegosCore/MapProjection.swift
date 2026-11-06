import Foundation

// Proyección equirrectangular de lon/lat a posición normalizada (0…1) sobre una lámina de mapa.
// Contrato compartido (lo usan el render del mapa, el generador de datos y los tests).

/// Ventana geográfica rectangular (equirrectangular) que cubre una lámina de mapa.
/// Convierte longitud/latitud en coordenadas normalizadas 0…1: x = oeste→este, y = norte→sur.
public struct GeoWindow: Codable, Hashable, Sendable {
    public var lonMin: Double
    public var lonMax: Double
    public var latMin: Double
    public var latMax: Double

    public init(lonMin: Double, lonMax: Double, latMin: Double, latMax: Double) {
        self.lonMin = lonMin; self.lonMax = lonMax; self.latMin = latMin; self.latMax = latMax
    }

    public var lonSpan: Double { lonMax - lonMin }
    public var latSpan: Double { latMax - latMin }

    /// Proyecta (lon, lat) a posición normalizada. No recorta: un punto fuera de la ventana da x o y fuera de 0…1.
    public func project(lon: Double, lat: Double) -> (x: Double, y: Double) {
        (x: (lon - lonMin) / lonSpan, y: (latMax - lat) / latSpan)
    }

    /// Ventana del Mediterráneo usada por la lámina `mapa-mediterraneo.jpg` (ya corregida por cos 38°).
    /// x = (lon + 10.6) / 48.0 ; y = (47.75 − lat) / 18.9123 ; aspect ≈ 2.0.
    public static let mediterranean = GeoWindow(lonMin: -10.6, lonMax: 37.4, latMin: 28.8377, latMax: 47.75)
}
