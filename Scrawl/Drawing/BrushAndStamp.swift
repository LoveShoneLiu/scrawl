import PencilKit
import SwiftUI
import UIKit

enum InkWidth: CGFloat, CaseIterable, Identifiable {
    case thin = 14
    case medium = 30
    case thick = 52

    var id: CGFloat { rawValue }

    var dotSize: CGFloat {
        switch self {
        case .thin: return 12
        case .medium: return 16
        case .thick: return 30
        }
    }
}

enum BrushKind: String, CaseIterable, Identifiable {
    case crayon
    case sketch
    case marker
    case watercolor

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .crayon: return "pencil.tip"
        case .sketch: return "pencil"
        case .marker: return "paintbrush.pointed.fill"
        case .watercolor: return "drop.fill"
        }
    }

    func makeTool(color: UIColor, width: InkWidth) -> PKInkingTool {
        PKInkingTool(inkType, color: color, width: resolvedWidth(width))
    }

    private var inkType: PKInkingTool.InkType {
        switch self {
        case .crayon: return .crayon
        case .sketch: return .pencil
        case .marker: return .marker
        case .watercolor: return .watercolor
        }
    }

    func resolvedWidth(_ width: InkWidth) -> CGFloat {
        switch (self, width) {
        case (.crayon, .thin): return 10
        case (.crayon, .medium): return 18
        case (.crayon, .thick): return 44
        case (.sketch, .thin): return 4
        case (.sketch, .medium): return 7
        case (.sketch, .thick): return 18
        case (.marker, .thin): return 12
        case (.marker, .medium): return 22
        case (.marker, .thick): return 40
        case (.watercolor, .thin): return 14
        case (.watercolor, .medium): return 24
        case (.watercolor, .thick): return 42
        }
    }
}

enum CreatureKind: String, Codable {
    case doodle
    case bigFish
    case smallFish
    case crab
    case tadpole
    case grass

    var huntsByDefault: Bool {
        switch self {
        case .bigFish, .smallFish, .crab: return true
        default: return false
        }
    }

    var grazes: Bool {
        self == .tadpole || self == .smallFish
    }

    var hidesInWeeds: Bool {
        self == .tadpole || self == .smallFish
    }

    var trappedByWeeds: Bool {
        self == .crab
    }

    var blockedByWeeds: Bool {
        self == .bigFish || self == .doodle
    }

    var eatsDecorFish: Bool {
        self == .bigFish || self == .crab || self == .doodle
    }

    func canEat(_ other: CreatureKind) -> Bool {
        switch self {
        case .bigFish, .doodle:
            return other == .smallFish || other == .tadpole
        case .smallFish:
            return other == .tadpole
        case .crab:
            return other == .smallFish || other == .tadpole
        case .tadpole, .grass:
            return false
        }
    }
}

enum StampKind: String, CaseIterable, Identifiable {
    case leaf
    case goldFish
    case blueFish
    case yellowFish
    case crab
    case tadpole

    var id: String { rawValue }

    var nativeColor: UIColor {
        switch self {
        case .leaf: return UIColor(red: 0.34, green: 0.72, blue: 0.28, alpha: 1)
        case .goldFish: return UIColor(red: 0.96, green: 0.48, blue: 0.16, alpha: 1)
        case .blueFish: return UIColor(red: 0.18, green: 0.52, blue: 0.92, alpha: 1)
        case .yellowFish: return UIColor(red: 0.98, green: 0.82, blue: 0.18, alpha: 1)
        case .crab: return UIColor(red: 0.92, green: 0.28, blue: 0.18, alpha: 1)
        case .tadpole: return UIColor(red: 0.32, green: 0.38, blue: 0.22, alpha: 1)
        }
    }

    var paperSize: ClosedRange<CGFloat> {
        switch self {
        case .goldFish: return 78...98
        case .blueFish: return 70...88
        case .yellowFish: return 48...64
        case .crab: return 64...82
        case .tadpole: return 44...58
        case .leaf: return 58...80
        }
    }

    func placedColor() -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nativeColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        switch self {
        case .goldFish, .blueFish, .yellowFish:
            return UIColor(
                hue: max(0, min(1, h + CGFloat.random(in: -0.03...0.03))),
                saturation: max(0.45, min(1, s + CGFloat.random(in: -0.06...0.05))),
                brightness: max(0.55, min(1, b + CGFloat.random(in: -0.08...0.06))),
                alpha: a
            )
        default:
            return nativeColor
        }
    }

    func iconImage(side: CGFloat = 72) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            draw(in: CGRect(x: 6, y: 6, width: side - 12, height: side - 12), color: nativeColor)
        }
    }

    func draw(in rect: CGRect, color: UIColor) {
        switch self {
        case .leaf:
            Self.leaf(in: rect, color: color)
        case .goldFish:
            Self.fish(in: rect, color: color, style: .round)
        case .blueFish:
            Self.fish(in: rect, color: color, style: .long)
        case .yellowFish:
            Self.fish(in: rect, color: color, style: .tiny)
        case .crab:
            Self.crab(in: rect, color: color)
        case .tadpole:
            Self.tadpole(in: rect, color: color)
        }
    }

    private enum FishStyle {
        case round, long, tiny
    }

    private static func leaf(in rect: CGRect, color: UIColor) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.maxY - 6))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 5, y: rect.minY + 6),
            controlPoint: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.22)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 4, y: rect.maxY - 6),
            controlPoint: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.maxY - rect.height * 0.1)
        )
        path.close()
        color.setFill()
        path.fill()
        color.darker(0.12).setFill()
        let tip = UIBezierPath()
        tip.move(to: CGPoint(x: rect.maxX - 8, y: rect.minY + 10))
        tip.addQuadCurve(
            to: CGPoint(x: rect.midX + 6, y: rect.midY + 4),
            controlPoint: CGPoint(x: rect.maxX - 4, y: rect.midY - 8)
        )
        tip.addQuadCurve(
            to: CGPoint(x: rect.maxX - 8, y: rect.minY + 10),
            controlPoint: CGPoint(x: rect.maxX - 18, y: rect.minY + 18)
        )
        tip.fill()
        UIColor.white.withAlphaComponent(0.55).setStroke()
        let vein = UIBezierPath()
        vein.move(to: CGPoint(x: rect.minX + 10, y: rect.maxY - 12))
        vein.addQuadCurve(
            to: CGPoint(x: rect.maxX - 12, y: rect.minY + 14),
            controlPoint: CGPoint(x: rect.midX, y: rect.midY)
        )
        vein.lineWidth = max(1.8, rect.width * 0.045)
        vein.lineCapStyle = .round
        vein.stroke()
    }

    private static func fish(in rect: CGRect, color: UIColor, style: FishStyle) {
        let body: CGRect
        let tailWidth: CGFloat
        switch style {
        case .round:
            body = CGRect(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.18, width: rect.width * 0.72, height: rect.height * 0.64)
            tailWidth = rect.width * 0.34
        case .long:
            body = CGRect(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.28, width: rect.width * 0.7, height: rect.height * 0.44)
            tailWidth = rect.width * 0.3
        case .tiny:
            body = CGRect(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.3, width: rect.width * 0.62, height: rect.height * 0.4)
            tailWidth = rect.width * 0.26
        }

        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: body.minX + 4, y: rect.midY))
        tail.addLine(to: CGPoint(x: rect.minX, y: rect.midY - tailWidth * 0.7))
        tail.addLine(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.midY))
        tail.addLine(to: CGPoint(x: rect.minX, y: rect.midY + tailWidth * 0.7))
        tail.close()
        color.darker(0.08).setFill()
        tail.fill()

        if style != .tiny {
            let fin = UIBezierPath()
            fin.move(to: CGPoint(x: body.midX - 4, y: body.minY + 2))
            fin.addLine(to: CGPoint(x: body.midX + 8, y: body.minY - rect.height * 0.12))
            fin.addLine(to: CGPoint(x: body.midX + 16, y: body.minY + 4))
            fin.close()
            color.darker(0.1).setFill()
            fin.fill()
        }

        color.setFill()
        UIBezierPath(ovalIn: body).fill()

        if style == .round {
            UIColor.white.withAlphaComponent(0.35).setFill()
            UIBezierPath(ovalIn: CGRect(
                x: body.midX + 2,
                y: body.minY + body.height * 0.18,
                width: body.width * 0.28,
                height: body.height * 0.22
            )).fill()
        }

        UIColor.white.setFill()
        let eyeR = style == .tiny ? rect.width * 0.055 : rect.width * 0.07
        UIBezierPath(ovalIn: CGRect(x: body.maxX - eyeR * 3.1, y: body.midY - eyeR * 1.5, width: eyeR * 2, height: eyeR * 2)).fill()
        UIColor.black.setFill()
        UIBezierPath(ovalIn: CGRect(x: body.maxX - eyeR * 2.5, y: body.midY - eyeR * 0.9, width: eyeR, height: eyeR)).fill()
    }

    private static func crab(in rect: CGRect, color: UIColor) {
        color.setStroke()
        let g = UIGraphicsGetCurrentContext()
        g?.setLineWidth(max(2.8, rect.width * 0.07))
        g?.setLineCap(.round)
        for i in 0..<3 {
            let y = rect.minY + rect.height * (0.42 + CGFloat(i) * 0.16)
            let left = UIBezierPath()
            left.move(to: CGPoint(x: rect.midX - rect.width * 0.16, y: rect.midY + 2))
            left.addLine(to: CGPoint(x: rect.minX + 1, y: y))
            left.stroke()
            let right = UIBezierPath()
            right.move(to: CGPoint(x: rect.midX + rect.width * 0.16, y: rect.midY + 2))
            right.addLine(to: CGPoint(x: rect.maxX - 1, y: y))
            right.stroke()
        }

        func claw(from start: CGPoint, mid: CGPoint, pin: CGPoint) {
            let arm = UIBezierPath()
            arm.move(to: start)
            arm.addLine(to: mid)
            arm.stroke()
            let pincer = UIBezierPath()
            pincer.move(to: mid)
            pincer.addLine(to: pin)
            pincer.stroke()
            let pincer2 = UIBezierPath()
            pincer2.move(to: mid)
            pincer2.addLine(to: CGPoint(x: pin.x + (start.x > rect.midX ? 5 : -5), y: pin.y + 6))
            pincer2.stroke()
        }
        claw(
            from: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.height * 0.4),
            mid: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.2),
            pin: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.06)
        )
        claw(
            from: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.minY + rect.height * 0.4),
            mid: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.2),
            pin: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.minY + rect.height * 0.06)
        )

        color.setFill()
        UIBezierPath(ovalIn: CGRect(
            x: rect.midX - rect.width * 0.3,
            y: rect.midY - rect.height * 0.2,
            width: rect.width * 0.6,
            height: rect.height * 0.46
        )).fill()
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: rect.midX - rect.width * 0.16, y: rect.midY - rect.height * 0.12, width: 9, height: 9)).fill()
        UIBezierPath(ovalIn: CGRect(x: rect.midX + rect.width * 0.05, y: rect.midY - rect.height * 0.12, width: 9, height: 9)).fill()
        UIColor.black.setFill()
        UIBezierPath(ovalIn: CGRect(x: rect.midX - rect.width * 0.14, y: rect.midY - rect.height * 0.1, width: 5, height: 5)).fill()
        UIBezierPath(ovalIn: CGRect(x: rect.midX + rect.width * 0.07, y: rect.midY - rect.height * 0.1, width: 5, height: 5)).fill()
    }

    private static func tadpole(in rect: CGRect, color: UIColor) {
        let tail = UIBezierPath()
        tail.move(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.midY - 2))
        tail.addQuadCurve(
            to: CGPoint(x: rect.maxX - 1, y: rect.midY - rect.height * 0.08),
            controlPoint: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + 2)
        )
        tail.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.midY + rect.height * 0.18))
        tail.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.midY + 10),
            controlPoint: CGPoint(x: rect.minX + rect.width * 0.78, y: rect.maxY - 4)
        )
        tail.close()
        UIColor(red: 0.55, green: 0.62, blue: 0.32, alpha: 0.95).setFill()
        tail.fill()

        color.setFill()
        UIBezierPath(ovalIn: CGRect(
            x: rect.minX + 2,
            y: rect.midY - rect.height * 0.26,
            width: rect.width * 0.48,
            height: rect.height * 0.52
        )).fill()
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: rect.minX + rect.width * 0.2, y: rect.midY - 9, width: 12, height: 12)).fill()
        UIColor.black.setFill()
        UIBezierPath(ovalIn: CGRect(x: rect.minX + rect.width * 0.25, y: rect.midY - 6, width: 6, height: 6)).fill()
    }
}

private extension UIColor {
    func darker(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, b - amount), alpha: a)
    }
}

struct PaperStamp: Identifiable, Equatable {
    let id: UUID
    let kind: StampKind
    let color: UIColor
    let normalizedPoint: CGPoint
    let rotation: CGFloat
    let size: CGFloat
}

struct PondDrop {
    let image: UIImage
    let kind: CreatureKind
    let hunts: Bool
    let skills: [CreatureSkill]
}
