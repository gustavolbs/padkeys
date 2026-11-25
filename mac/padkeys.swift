// padkeys: (1) global hotkeys F13/F16-F20 run commands (e.g. open an app); (2) menu bar icon with a mini layout of the Togkey Pad Plus.
// Everything is configured in ~/.config/padkeys/config.json (override with $PADKEYS_CONFIG). Hotkeys are read at start-up;
// the mini layout is re-read on every click. F14/F15 are not supported: macOS uses them for screen brightness.
import AppKit
import Carbon
import IOKit.hid
import SwiftUI

let home = NSHomeDirectory()
let configURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PADKEYS_CONFIG"] ?? home + "/.config/padkeys/config.json")
// macOS virtual key codes of the keys the keyboard can send without side effects
let keyCodes: [String: UInt32] = ["F13": 105, "F16": 106, "F17": 64, "F18": 79, "F19": 80, "F20": 90]

func run(_ a: [String]) {
  let p = Process(); p.executableURL = URL(fileURLWithPath: a[0]); p.arguments = Array(a.dropFirst())
  try? p.run()
}

// MARK: pad display (raw HID, needs the custom firmware in ../firmware)
// Order = icon id in the firmware (icons.h). Keep both lists in sync.
let iconNames = ["spotify", "mic_slash", "claude", "slack", "layers", "close", "mission", "reopen", "left", "right",
                 "play", "prev", "next", "mute", "globe", "terminal", "mail", "code"]

func asciiLine(_ s: String) -> String {
  let f = s.folding(options: [.diacriticInsensitive], locale: nil)
  return String(f.unicodeScalars.filter { $0.value >= 32 && $0.value < 127 }.map { Character($0) }.prefix(29))
}

// Opens the raw HID interface (usage page 0xFF60 / usage 0x61) only while sending, without seizing it, so Vial still works.
func sendReports(_ reports: [[UInt8]]) -> Bool {
  let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
  IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: 0xFEED, kIOHIDProductIDKey: 0x8687,
                                    kIOHIDPrimaryUsagePageKey: 0xFF60, kIOHIDPrimaryUsageKey: 0x61] as CFDictionary)
  guard IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
        let devs = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice>, let dev = devs.first else { return false }
  var ok = true
  for rep in reports {
    var r = rep + [UInt8](repeating: 0, count: max(0, 32 - rep.count))
    ok = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0, &r, 32) == kIOReturnSuccess && ok
  }
  IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
  return ok
}

// One report per grid cell: [0xD1, layer, cell, icon id or 0xFF, up to 3 tag chars]
func cellReports(_ c: Config) -> [[UInt8]] {
  var out: [[UInt8]] = []
  for (i, layer) in (c.layers ?? []).enumerated() {
    let n = layer.layer ?? i
    guard (0..<4).contains(n) else { continue }
    let cells = layer.keys.prefix(2).flatMap { $0.prefix(3) }.enumerated().filter { $0.element.oled != nil || $0.element.tag != nil }
    if cells.isEmpty { continue }
    for r in 0..<2 { for col in 0..<3 {
      let key = r < layer.keys.count && col < layer.keys[r].count ? layer.keys[r][col] : nil
      let icon = key?.oled.flatMap { iconNames.firstIndex(of: $0) }.map { UInt8($0) } ?? 0xFF
      out.append([0xD1, UInt8(n), UInt8(r * 3 + col), icon] + Array(asciiLine(key?.tag ?? "").utf8.prefix(3)))
    } }
  }
  return out
}

let npQueue = DispatchQueue(label: "padkeys.display")
var npErr = ""; var npLast = "\u{1}"; var cellsLast: [[UInt8]] = []; var padAt = Date.distantPast
func syncPad() {
  npQueue.async {
    guard let cfg = loadConfig() else { return }
    var text = ""
    if cfg.nowPlaying == true, !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty {
      let src = "tell application \"Spotify\"\nif player state is playing then return (artist of current track) & \" - \" & (name of current track)\nreturn \"\"\nend tell"
      var err: NSDictionary?
      text = NSAppleScript(source: src)?.executeAndReturnError(&err).stringValue ?? ""
      if let e = err, npErr != "\(e)" { npErr = "\(e)"; FileHandle.standardError.write("spotify script error: \(e)\n".data(using: .utf8)!) }
    }
    let line = asciiLine(text), cells = cellReports(cfg)
    // Resend every 20 s even if nothing changed: the pad may have been replugged, and it clears the line after 60 s
    guard line != npLast || cells != cellsLast || Date().timeIntervalSince(padAt) > 20 else { return }
    var reports = cells
    if cfg.nowPlaying == true { reports.append([0xD0, 1] + Array(line.utf8)) }
    if !reports.isEmpty { if sendReports(reports) { npLast = line; cellsLast = cells; padAt = Date() } else if npErr != "send" { npErr = "send"; FileHandle.standardError.write("pad not reachable (HID open/send failed)\n".data(using: .utf8)!) } }
  }
}

// MARK: layout model
// A key is a plain string (texto) ou {"label","app":"/caminho.app","symbol":"sf.symbol"}
struct Key: Decodable {
  let label: String; let app: String?; let symbol: String?; let oled: String?; let tag: String?
  enum CK: String, CodingKey { case label, app, symbol, oled, tag }
  init(from d: Decoder) throws {
    if let s = try? d.singleValueContainer().decode(String.self) { label = s; app = nil; symbol = nil; oled = nil; tag = nil; return }
    let c = try d.container(keyedBy: CK.self)
    label = (try? c.decode(String.self, forKey: .label)) ?? ""
    app = try? c.decode(String.self, forKey: .app)
    symbol = try? c.decode(String.self, forKey: .symbol)
    oled = try? c.decode(String.self, forKey: .oled)
    tag = try? c.decode(String.self, forKey: .tag)
  }
}
struct Layer: Decodable { let name: String; let layer: Int?; let turn: String?; let press: String?; let keys: [[Key]] }
struct Hotkey: Decodable { let key: String; let command: [String] }
struct Config: Decodable { let hotkeys: [Hotkey]?; let nowPlaying: Bool?; let layers: [Layer]? }

func loadConfig() -> Config? {
  guard let d = try? Data(contentsOf: configURL) else { return nil }
  do { return try JSONDecoder().decode(Config.self, from: d) }
  catch { FileHandle.standardError.write("config error: \(error)\n".data(using: .utf8)!); return nil }
}

func loadLayout() -> Config {
  loadConfig() ?? Config(hotkeys: nil, nowPlaying: nil, layers: [Layer(name: "config.json not found or invalid (see padkeys.log)", layer: nil, turn: nil, press: nil, keys: [])])
}

// MARK: UI
struct KeyCap: View {
  let key: Key
  var body: some View {
    VStack(spacing: 3) {
      if let app = key.app {
        Image(nsImage: NSWorkspace.shared.icon(forFile: app)).resizable().frame(width: 30, height: 30)
      } else if let sym = key.symbol {
        Image(systemName: sym).font(.system(size: 20, weight: .regular)).frame(height: 30)
      }
      if !key.label.isEmpty {
        Text(key.label).font(.system(size: key.app == nil && key.symbol == nil ? 11 : 9, weight: .medium)).multilineTextAlignment(.center)
      }
    }
    .frame(width: 78, height: 54)
    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.18)))
  }
}

struct LayerView: View {
  let layer: Layer
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(layer.name).font(.headline)
      HStack(spacing: 6) {  // top of the pad: OLED screen + rotary encoder
        RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.85)).frame(width: 78, height: 26)
          .overlay(Text("screen").font(.system(size: 9)).foregroundColor(.gray))
        VStack(alignment: .leading, spacing: 1) {
          if let t = layer.turn { Text("Turn: \(t)").font(.system(size: 10)) }
          if let p = layer.press { Text("Press: \(p)").font(.system(size: 10)) }
        }
        .frame(width: 150, alignment: .leading)
        Circle().fill(Color.primary.opacity(0.75)).frame(width: 26, height: 26)
      }
      ForEach(0..<layer.keys.count, id: \.self) { r in
        HStack(spacing: 6) { ForEach(0..<layer.keys[r].count, id: \.self) { c in KeyCap(key: layer.keys[r][c]) } }
      }
    }
  }
}

struct PopoverView: View {
  let layout: Config
  var body: some View {
    HStack(alignment: .top, spacing: 22) { ForEach(0..<(layout.layers ?? []).count, id: \.self) { LayerView(layer: layout.layers![$0]) } }
      .padding(16)
  }
}

// MARK: app
final class App: NSObject, NSApplicationDelegate {
  let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  let popover = NSPopover()

  func applicationDidFinishLaunching(_ n: Notification) {
    if let b = item.button {
      b.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Togkey Pad Plus")
      b.target = self; b.action = #selector(toggle)
    }
    popover.behavior = .transient
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in syncPad() }  // no-op without the custom firmware
    if CommandLine.arguments.contains("--show") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.toggle() } }
  }

  @objc func toggle() {
    if popover.isShown { popover.performClose(nil); return }
    popover.contentViewController = NSHostingController(rootView: PopoverView(layout: loadLayout()))
    if let b = item.button { popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY) }
    NSApp.activate(ignoringOtherApps: true)
  }
}

// MARK: hotkeys
let actions: [(UInt32, [String])] = (loadConfig()?.hotkeys ?? []).compactMap { h in
  guard let code = keyCodes[h.key.uppercased()], !h.command.isEmpty else {
    FileHandle.standardError.write("ignored hotkey \(h.key): unsupported key (use F13, F16-F20) or empty command\n".data(using: .utf8)!)
    return nil
  }
  return (code, h.command.map { ($0 as NSString).expandingTildeInPath })
}

var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetApplicationEventTarget(), { _, ev, _ in
  var id = EventHotKeyID()
  GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &id)
  run(actions[Int(id.id)].1)
  return noErr
}, 1, &spec, nil, nil)

for (i, a) in actions.enumerated() {
  var ref: EventHotKeyRef?
  let st = RegisterEventHotKey(a.0, 0, EventHotKeyID(signature: 0x504B5953, id: UInt32(i)), GetApplicationEventTarget(), 0, &ref)
  FileHandle.standardError.write("hotkey \(a.0) -> \(a.1.joined(separator: " ")): status \(st)\n".data(using: .utf8)!)
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
