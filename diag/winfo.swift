// Mesure le placement des fenêtres d'un processus par rapport à la zone utile
// de l'écran (visibleFrame : sous la barre de menus, hors Dock).
//
//   swift winfo.swift <pid>
//
// Coordonnées en points, origine en haut à gauche de l'écran principal
// (convention CGWindowList). Code de sortie 0 si toutes les fenêtres
// « normales » (layer 0) sont entièrement dans la zone utile, 1 sinon,
// 2 si aucune fenêtre trouvée.

import AppKit
import CoreGraphics

let pid = Int32(CommandLine.arguments[1])!
let main = NSScreen.screens[0]
let full = main.frame
let vis = main.visibleFrame
// visibleFrame est en coordonnées Cocoa (origine en bas à gauche) : conversion
let visTop = full.maxY - vis.maxY
let usable = CGRect(x: vis.minX, y: visTop, width: vis.width, height: vis.height)
print(String(format: "écran %.0fx%.0f scale=%.1f, zone utile x=%.0f y=%.0f w=%.0f h=%.0f (barre de menus %.0f pt)",
             full.width, full.height, main.backingScaleFactor,
             usable.minX, usable.minY, usable.width, usable.height, visTop))

let infos = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
var found = 0, bad = 0
for w in infos where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
  let layer = w[kCGWindowLayer as String] as? Int ?? -1
  guard layer == 0, let b = w[kCGWindowBounds as String] as? NSDictionary,
        let r = CGRect(dictionaryRepresentation: b), r.width > 50, r.height > 50 else { continue }
  found += 1
  // Le cadre inclut l'ombre des décorations GTK (≈ 23 pt en haut, 26 pt
  // sur les côtés) : on la tolère, pas davantage.
  let ok = usable.insetBy(dx: -30, dy: -30).contains(r)
  if !ok { bad += 1 }
  print(String(format: "fenêtre \"%@\" x=%.0f y=%.0f w=%.0f h=%.0f onscreen=%@ -> %@",
               (w[kCGWindowName as String] as? String) ?? "?", r.minX, r.minY, r.width, r.height,
               String(describing: w[kCGWindowIsOnscreen as String] ?? false),
               ok ? "OK" : "HORS ZONE UTILE"))
}
exit(found == 0 ? 2 : (bad == 0 ? 0 : 1))
