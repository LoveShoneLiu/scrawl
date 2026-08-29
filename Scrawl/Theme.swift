import SwiftUI
import UIKit

enum Palette {
    static let paper = Color(red: 0.988, green: 0.965, blue: 0.918)
    static let paperUI = UIColor(red: 0.988, green: 0.965, blue: 0.918, alpha: 1)
    static let desk = Color(red: 0.76, green: 0.70, blue: 0.61)
    static let tray = Color.white
    static let trayLine = Color(red: 0.86, green: 0.81, blue: 0.74)
    static let paperEdge = Color(red: 0.22, green: 0.52, blue: 0.58)
    static let pondTop = UIColor(red: 0.55, green: 0.82, blue: 0.84, alpha: 1)
    static let pondBottom = UIColor(red: 0.31, green: 0.62, blue: 0.68, alpha: 1)
    static let inkWidth: CGFloat = 28
    static let minHit: CGFloat = 120

    static let swatches: [UIColor] = [
        UIColor(red: 0.89, green: 0.24, blue: 0.16, alpha: 1),
        UIColor(red: 0.96, green: 0.63, blue: 0.13, alpha: 1),
        UIColor(red: 0.96, green: 0.84, blue: 0.26, alpha: 1),
        UIColor(red: 0.24, green: 0.71, blue: 0.29, alpha: 1),
        UIColor(red: 0.23, green: 0.49, blue: 0.87, alpha: 1),
        UIColor(red: 0.56, green: 0.31, blue: 0.78, alpha: 1),
        UIColor(red: 0.95, green: 0.40, blue: 0.62, alpha: 1),
        UIColor(red: 0.48, green: 0.28, blue: 0.16, alpha: 1)
    ]
}

struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amount: CGFloat = 14

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(shakes * .pi * 3)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
