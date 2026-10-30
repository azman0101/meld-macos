// Double-clic souris à une position de l'écran (points, origine en haut à
// gauche, comme CGWindowList).
//
//   swift click.swift <x> <y>

import CoreGraphics
import Foundation

let p = CGPoint(x: Double(CommandLine.arguments[1])!, y: Double(CommandLine.arguments[2])!)
for n in 1...2 {
  for type in [CGEventType.leftMouseDown, .leftMouseUp] {
    let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!
    e.setIntegerValueField(.mouseEventClickState, value: Int64(n))
    e.post(tap: .cghidEventTap)
    usleep(30_000)
  }
}
