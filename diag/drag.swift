// Glisser-déposer à la souris, en points (origine en haut à gauche, comme
// CGWindowList). Le curseur est déplacé par petits pas, comme une main.
//
//   swift drag.swift <x1> <y1> <x2> <y2>

import CoreGraphics
import Foundation

let a = CommandLine.arguments.dropFirst().map { Double($0)! }
let from = CGPoint(x: a[0], y: a[1]), to = CGPoint(x: a[2], y: a[3])

func post(_ type: CGEventType, _ p: CGPoint) {
  CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!
    .post(tap: .cghidEventTap)
}

post(.mouseMoved, from); usleep(300_000)
post(.leftMouseDown, from); usleep(300_000)
let steps = 60
for i in 1...steps {
  let t = Double(i) / Double(steps)
  post(.leftMouseDragged, CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
  usleep(20_000)
}
usleep(300_000)
post(.leftMouseUp, to)
