import AppKit

// Colours from the Windows UI spec (src/ThemeTokens.cpp, Accent.cpp). Solid style.
func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func mix(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
    let x = a.usingColorSpace(.sRGB)!, y = b.usingColorSpace(.sRGB)!
    return NSColor(srgbRed: x.redComponent + (y.redComponent - x.redComponent) * t, green: x.greenComponent + (y.greenComponent - x.greenComponent) * t,
                   blue: x.blueComponent + (y.blueComponent - x.blueComponent) * t, alpha: x.alphaComponent + (y.alphaComponent - x.alphaComponent) * t)
}

struct Palette {
    var dark: Bool
    var accent, accentHi, textOnAccent, accentMark: NSColor
    var text, textDim, subtleText, shadow: NSColor
    var disc, discLine, tile, tileLine, centre, centreLine, dot: NSColor

    /// Tide: fill 12A58E, dark tone 2DD4B4, light tone 0B7A69.
    static func make(dark: Bool) -> Palette {
        let light = rgb(0x0B7A69), darkTone = rgb(0x2DD4B4)
        let accent = light   // the hovered tile and active section use the light tone with white text in both themes
        let accentHi = mix(light, .white, 0.20)
        if dark {
            return Palette(dark: true, accent: accent, accentHi: accentHi, textOnAccent: .white, accentMark: darkTone,
                           text: rgb(0xEEF0F3), textDim: rgb(0xEEF0F3, 0.38), subtleText: rgb(0xA9AEB8), shadow: rgb(0x000000, 0.5),
                           disc: rgb(0x1A1C22), discLine: rgb(0xFFFFFF, 0.08), tile: rgb(0x2A2D35), tileLine: rgb(0xFFFFFF, 0.06),
                           centre: rgb(0x141619), centreLine: rgb(0xFFFFFF, 0.08), dot: rgb(0xEEF0F3, 0.28))
        }
        return Palette(dark: false, accent: accent, accentHi: accentHi, textOnAccent: .white, accentMark: light,
                       text: rgb(0x1B1D23), textDim: rgb(0x1B1D23, 0.38), subtleText: rgb(0x5E6370), shadow: rgb(0x14161E, 0.18),
                       disc: rgb(0xFFFFFF), discLine: rgb(0x15171E, 0.10), tile: rgb(0xEEF0F3), tileLine: rgb(0xD5D8DE),
                       centre: rgb(0xFFFFFF), centreLine: rgb(0x15171E, 0.10), dot: rgb(0x1B1D23, 0.25))
    }
}
