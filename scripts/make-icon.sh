#!/bin/zsh
# Compose AppIcon.icns from the CC0 tortoise illustration (assets/tortoise.svg,
# openclipart.org/detail/2157, public domain). Squircle base in Catppuccin Latte,
# tortoise centred. Regenerate with: scripts/make-icon.sh
set -euo pipefail

cd "$(dirname "$0")/.."

swift - <<'SWIFT'
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Squircle base — Catppuccin Latte base, calm and light so the woodcut lines read.
let inset: CGFloat = size * 0.05
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = rect.width * 0.2237
NSColor(srgbRed: 0xEF / 255, green: 0xF1 / 255, blue: 0xF5 / 255, alpha: 1).setFill()
NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

// The tortoise, centred at 72% of the canvas, mirrored to face right.
guard let tortoise = NSImage(contentsOfFile: "assets/tortoise.svg") else {
    fatalError("assets/tortoise.svg missing or unreadable")
}
let aspect = tortoise.size.height / tortoise.size.width
let width = size * 0.72
let height = width * aspect
if let cg = NSGraphicsContext.current?.cgContext {
    cg.saveGState()
    cg.translateBy(x: size, y: 0)
    cg.scaleBy(x: -1, y: 1)
    tortoise.draw(
        in: NSRect(x: (size - width) / 2, y: (size - height) / 2, width: width, height: height),
        from: .zero, operation: .sourceOver, fraction: 1
    )
    cg.restoreGState()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not render icon png")
}
try png.write(to: URL(fileURLWithPath: ".build/AppIcon-1024.png"))
print("rendered .build/AppIcon-1024.png")
SWIFT

ICONSET=.build/AppIcon.iconset
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s .build/AppIcon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d .build/AppIcon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o assets/AppIcon.icns
echo "built assets/AppIcon.icns"
