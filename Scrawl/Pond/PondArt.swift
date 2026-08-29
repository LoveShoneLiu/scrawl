import SpriteKit
import UIKit

enum PondArt {
    static func water(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let g = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 0.42, green: 0.74, blue: 0.70, alpha: 1).cgColor,
                UIColor(red: 0.22, green: 0.55, blue: 0.58, alpha: 1).cgColor,
                UIColor(red: 0.10, green: 0.36, blue: 0.42, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1]) {
                g.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: 0, y: 0), options: [])
            }

            g.setFillColor(UIColor(red: 0.55, green: 0.84, blue: 0.80, alpha: 0.22).cgColor)
            g.fillEllipse(in: CGRect(x: size.width * 0.08, y: size.height * 0.12, width: size.width * 0.55, height: size.height * 0.38))
            g.setFillColor(UIColor(red: 0.12, green: 0.42, blue: 0.46, alpha: 0.28).cgColor)
            g.fillEllipse(in: CGRect(x: size.width * 0.45, y: size.height * 0.42, width: size.width * 0.5, height: size.height * 0.4))
            g.setFillColor(UIColor(red: 0.08, green: 0.3, blue: 0.34, alpha: 0.22).cgColor)
            g.fillEllipse(in: CGRect(x: size.width * -0.05, y: size.height * 0.55, width: size.width * 0.4, height: size.height * 0.38))

            g.setStrokeColor(UIColor.white.withAlphaComponent(0.14).cgColor)
            g.setLineWidth(2)
            for i in 0..<7 {
                let y = size.height * (0.18 + CGFloat(i) * 0.1)
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 0, y: y))
                path.addCurve(
                    to: CGPoint(x: size.width, y: y + 8),
                    controlPoint1: CGPoint(x: size.width * 0.33, y: y - 10),
                    controlPoint2: CGPoint(x: size.width * 0.66, y: y + 14)
                )
                g.addPath(path.cgPath)
            }
            g.strokePath()

            g.setFillColor(UIColor(red: 0.07, green: 0.28, blue: 0.30, alpha: 0.4).cgColor)
            g.fill(CGRect(x: 0, y: size.height * 0.86, width: size.width, height: size.height * 0.14))

            g.setFillColor(UIColor.white.withAlphaComponent(0.32).cgColor)
            g.fill(CGRect(x: 0, y: 0, width: size.width, height: 7))
        }
    }

    static func lilyPad(radius: CGFloat, flower: Bool) -> UIImage {
        let side = radius * 2 + 28
        let size = CGSize(width: side, height: flower ? side + 18 : side)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let g = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: flower ? size.height / 2 + 6 : size.height / 2)

            g.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: UIColor(red: 0.05, green: 0.2, blue: 0.22, alpha: 0.35).cgColor)
            g.setFillColor(UIColor(red: 0.18, green: 0.42, blue: 0.22, alpha: 0.55).cgColor)
            g.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius + 6, width: radius * 2, height: radius * 2 * 0.72))
            g.setShadow(offset: .zero, blur: 0, color: nil)

            let pad = lilyPath(center: center, radius: radius)
            g.saveGState()
            g.addPath(pad.cgPath)
            g.clip()
            let padColors = [
                UIColor(red: 0.42, green: 0.72, blue: 0.28, alpha: 1).cgColor,
                UIColor(red: 0.22, green: 0.52, blue: 0.20, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: padColors, locations: [0, 1]) {
                g.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: center.x - radius * 0.25, y: center.y - radius * 0.2),
                    startRadius: 2,
                    endCenter: center,
                    endRadius: radius,
                    options: [.drawsAfterEndLocation]
                )
            }

            g.restoreGState()
            g.addPath(pad.cgPath)
            g.setStrokeColor(UIColor(red: 0.14, green: 0.36, blue: 0.16, alpha: 0.9).cgColor)
            g.setLineWidth(2)
            g.strokePath()

            g.setStrokeColor(UIColor(red: 0.16, green: 0.4, blue: 0.18, alpha: 0.45).cgColor)
            g.setLineWidth(1)
            for i in 0..<7 {
                let angle = CGFloat(i) * .pi / 4 + 0.2
                g.move(to: center)
                g.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 0.82, y: center.y + sin(angle) * radius * 0.82))
            }
            g.strokePath()

            if flower {
                drawLotus(at: CGPoint(x: center.x, y: center.y - radius * 0.12), radius: radius * 0.42)
            }
        }
    }

    static func fish(length: CGFloat, body: UIColor, belly: UIColor, spots: Bool) -> UIImage {
        let size = CGSize(width: length, height: length * 0.58)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let g = ctx.cgContext
            let bodyRect = CGRect(x: size.width * 0.18, y: size.height * 0.22, width: size.width * 0.62, height: size.height * 0.52)

            g.setFillColor(body.withAlphaComponent(0.95).cgColor)
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.48))
            tail.addLine(to: CGPoint(x: size.width * 0.02, y: size.height * 0.18))
            tail.addLine(to: CGPoint(x: size.width * 0.08, y: size.height * 0.48))
            tail.addLine(to: CGPoint(x: size.width * 0.02, y: size.height * 0.8))
            tail.close()
            g.addPath(tail.cgPath)
            g.fillPath()

            let dorsal = UIBezierPath()
            dorsal.move(to: CGPoint(x: size.width * 0.48, y: size.height * 0.26))
            dorsal.addLine(to: CGPoint(x: size.width * 0.58, y: size.height * 0.04))
            dorsal.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.26))
            dorsal.close()
            g.setFillColor(body.withAlphaComponent(0.8).cgColor)
            g.addPath(dorsal.cgPath)
            g.fillPath()

            g.addEllipse(in: bodyRect)
            g.clip()
            let fishColors = [belly.cgColor, body.cgColor, body.darker(0.18).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fishColors, locations: [0, 0.45, 1]) {
                g.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: size.height),
                    end: CGPoint(x: 0, y: 0),
                    options: []
                )
            }
            if spots {
                g.setFillColor(UIColor.white.withAlphaComponent(0.75).cgColor)
                g.fillEllipse(in: CGRect(x: size.width * 0.42, y: size.height * 0.3, width: size.width * 0.12, height: size.height * 0.16))
                g.setFillColor(UIColor(red: 0.75, green: 0.12, blue: 0.1, alpha: 0.85).cgColor)
                g.fillEllipse(in: CGRect(x: size.width * 0.58, y: size.height * 0.38, width: size.width * 0.1, height: size.height * 0.14))
            }
            g.resetClip()

            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: size.width * 0.7, y: size.height * 0.34, width: size.height * 0.16, height: size.height * 0.16)).fill()
            UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: size.width * 0.74, y: size.height * 0.38, width: size.height * 0.08, height: size.height * 0.08)).fill()
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: size.width * 0.76, y: size.height * 0.39, width: 3, height: 3)).fill()
        }
    }

    static func reed() -> UIImage {
        let size = CGSize(width: 28, height: 90)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            UIColor(red: 0.28, green: 0.48, blue: 0.22, alpha: 1).setStroke()
            let stem = UIBezierPath()
            stem.lineWidth = 3
            stem.move(to: CGPoint(x: 14, y: 90))
            stem.addQuadCurve(to: CGPoint(x: 16, y: 18), controlPoint: CGPoint(x: 6, y: 50))
            stem.stroke()
            UIColor(red: 0.42, green: 0.32, blue: 0.14, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 10, y: 6, width: 9, height: 22), cornerRadius: 4).fill()
        }
    }

    static func seaweed() -> UIImage {
        let size = CGSize(width: 72, height: 96)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 3
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let blades: [(CGFloat, UIColor, CGFloat)] = [
                (18, UIColor(red: 0.16, green: 0.48, blue: 0.28, alpha: 0.95), 8),
                (36, UIColor(red: 0.22, green: 0.58, blue: 0.30, alpha: 0.95), 14),
                (54, UIColor(red: 0.18, green: 0.42, blue: 0.24, alpha: 0.95), -6)
            ]
            for (x, color, bend) in blades {
                color.setStroke()
                let path = UIBezierPath()
                path.lineWidth = 7
                path.lineCapStyle = .round
                path.move(to: CGPoint(x: x, y: 92))
                path.addQuadCurve(
                    to: CGPoint(x: x + bend, y: 12),
                    controlPoint: CGPoint(x: x - bend * 1.4, y: 52)
                )
                path.stroke()
                color.withAlphaComponent(0.55).setFill()
                UIBezierPath(ovalIn: CGRect(x: x + bend - 7, y: 6, width: 14, height: 18)).fill()
            }
        }
    }

    private static func lilyPath(center: CGPoint, radius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let notch: CGFloat = 0.22
        path.move(to: CGPoint(x: center.x + radius, y: center.y))
        for i in 1...32 {
            let t = CGFloat(i) / 32
            var angle = t * .pi * 2
            var r = radius
            let dist = min(abs(t), abs(t - 1))
            if dist < notch {
                r *= 0.15 + 0.85 * (dist / notch)
            }
            angle -= 0.15
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r * 0.86)
            path.addLine(to: point)
        }
        path.close()
        return path
    }

    private static func drawLotus(at center: CGPoint, radius: CGFloat) {
        let petalColor = UIColor(red: 0.95, green: 0.62, blue: 0.72, alpha: 1)
        let inner = UIColor(red: 0.98, green: 0.78, blue: 0.84, alpha: 1)
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let path = UIBezierPath(
                ovalIn: CGRect(x: -radius * 0.28, y: -radius * 0.85, width: radius * 0.56, height: radius * 0.95)
            )
            guard let ctx = UIGraphicsGetCurrentContext() else { continue }
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: angle)
            (i.isMultiple(of: 2) ? petalColor : inner).setFill()
            path.fill()
            ctx.restoreGState()
        }
        UIColor(red: 0.98, green: 0.84, blue: 0.28, alpha: 1).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 0.22, y: center.y - radius * 0.22, width: radius * 0.44, height: radius * 0.44)).fill()
    }
}

private extension UIColor {
    func darker(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, b - amount), alpha: a)
    }
}
