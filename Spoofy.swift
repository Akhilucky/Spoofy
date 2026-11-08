import SwiftUI
import MapKit
import AppKit
import UniformTypeIdentifiers

@main struct SpoofyApp: App {
    @StateObject var model = Model()
    var body: some Scene { WindowGroup { ContentView().environmentObject(model).frame(minWidth: 900, minHeight: 620) } }
}

final class ReadyFlag {
    private let lock = NSLock(); private var value = false
    func set() { lock.lock(); value = true; lock.unlock() }
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
}
final class Model: ObservableObject {
    @Published var latitude = "37.3349"
    @Published var longitude = "-122.0090"
    @Published var search = ""
    @Published var status = "Connect and unlock your iPhone, then trust this Mac."
    @Published var log = ""
    @Published var modern = true
    @Published var wireless = false
    @Published var busy = false
    @Published var route: [CLLocationCoordinate2D] = []
    @Published var running = false
    @Published var favorites: [Favorite] = []
    @Published var history: [Favorite] = []
    var activeSession: Process?
    @Published var speed = 5.0
    @Published var step = 50.0
    @Published var center = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    init() {
        if let data = UserDefaults.standard.data(forKey: "savedLocations"), let saved = try? JSONDecoder().decode([Favorite].self, from: data) { favorites = saved }
        if let data = UserDefaults.standard.data(forKey: "locationHistory"), let saved = try? JSONDecoder().decode([Favorite].self, from: data) { history = saved }
    }
    func recordHistory(_ p: CLLocationCoordinate2D) {
        history.removeAll { abs($0.latitude-p.latitude) < 0.000001 && abs($0.longitude-p.longitude) < 0.000001 }
        let name = String(format: "%.6f, %.6f", p.latitude, p.longitude)
        history.insert(Favorite(name: name, latitude: p.latitude, longitude: p.longitude), at: 0)
        history = Array(history.prefix(20))
        if let data = try? JSONEncoder().encode(history) { UserDefaults.standard.set(data, forKey: "locationHistory") }
    }
    func clearHistory() { history.removeAll(); UserDefaults.standard.removeObject(forKey: "locationHistory") }
    func saveFavorite() {
        guard let p = selected else { status = "Enter valid coordinates."; return }
        let title = search.trimmingCharacters(in: .whitespacesAndNewlines)
        favorites.append(Favorite(name: title.isEmpty ? String(format: "%.4f, %.4f", p.latitude, p.longitude) : title, latitude: p.latitude, longitude: p.longitude))
        persistFavorites(); status = "Location saved on this Mac."
    }
    func persistFavorites() { if let data = try? JSONEncoder().encode(favorites) { UserDefaults.standard.set(data, forKey: "savedLocations") } }
    func deleteFavorite(_ id: UUID) { favorites.removeAll { $0.id == id }; persistFavorites() }
    func importGPX() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "gpx") ?? .xml, .xml]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let parser = XMLParser(contentsOf: url) else { status = "Could not open GPX file."; return }
        let delegate = GPXReader(); parser.delegate = delegate
        guard parser.parse(), !delegate.points.isEmpty else { status = "GPX has no valid route or track points."; return }
        route = delegate.points; select(route[0], recenter: true); status = "Imported \(route.count) GPX points."
    }
    func exportGPX() {
        guard !route.isEmpty else { status = "Add route points first."; return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "route.gpx"; panel.allowedContentTypes = [UTType(filenameExtension: "gpx") ?? .xml]; panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let points = route.map { "<rtept lat=\"\($0.latitude)\" lon=\"\($0.longitude)\"/>" }.joined(separator: "\n")
        let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\" creator=\"Spoofy\" xmlns=\"http://www.topografix.com/GPX/1/1\"><rte>\n\(points)\n</rte></gpx>"
        do { try xml.write(to: url, atomically: true, encoding: .utf8); status = "GPX route saved." } catch { status = "Could not save route: \(error.localizedDescription)" }
    }
    func followRoads() {
        guard route.count >= 2 else { status = "Add at least two waypoints first."; return }
        let waypoints = route; busy = true; status = "Finding walking directions…"
        var result: [CLLocationCoordinate2D] = []
        func segment(_ index: Int) {
            if index >= waypoints.count - 1 { self.route = result; self.busy = false; self.status = "Walking route ready: \(result.count) points."; return }
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[index]))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[index+1]))
            request.transportType = .walking
            MKDirections(request: request).calculate { response, error in
                guard let line = response?.routes.first?.polyline, error == nil else { self.busy = false; self.status = "Directions failed: \(error?.localizedDescription ?? "No route found"). Original waypoints kept."; return }
                let points = line.points()
                for i in 0..<line.pointCount { if index == 0 || i > 0 { result.append(points[i].coordinate) } }
                segment(index + 1)
            }
        }
        segment(0)
    }
    var timer: Timer?
    var targetIndex = 1
    var lastTick = Date()
    var selected: CLLocationCoordinate2D? {
        guard let lat = Double(latitude), let lon = Double(longitude), lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    func select(_ p: CLLocationCoordinate2D, recenter: Bool = false) {
        latitude = String(format: "%.6f", p.latitude); longitude = String(format: "%.6f", p.longitude)
        if recenter { center = p }
    }
    func find() {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        status = "Searching…"
        CLGeocoder().geocodeAddressString(q) { places, error in
            DispatchQueue.main.async {
                if let p = places?.first?.location?.coordinate { self.select(p, recenter: true); self.status = "Place found. Set location or add it to a route." }
                else { self.status = "Search failed: \(error?.localizedDescription ?? "No results")" }
            }
        }
    }
    func execute(_ action: String, point: CLLocationCoordinate2D? = nil, completion: ((Bool)->Void)? = nil) {
        guard !busy else { return }
        guard action != "set" || point != nil else { status = "Enter valid coordinates."; return }
        let bundledBackend = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/spoofy-backend").path
        let customPython = Bundle.main.object(forInfoDictionaryKey: "OpenLocationPython") as? String
        let python = customPython ?? bundledBackend
        var args = customPython == nil ? [String]() : ["-m", "pymobiledevice3"]
        if action == "reveal" {
            args += ["amfi", "reveal-developer-mode"]
        } else if action == "wifi" {
            args += ["lockdown", "wifi-connections", "on"]
        } else {
            args.append("developer")
            if modern { args.append("dvt") }
            args += ["simulate-location", action]
            if wireless { args.append("--mobdev2") }
        }
        if let p = point { args += ["--", String(p.latitude), String(p.longitude)] }
        let persistent = action == "set" && modern
        let previous = (action == "set" || action == "clear") ? activeSession : nil
        if previous != nil { activeSession = nil }
        busy = true; status = action == "wifi" ? "Enabling Wi-Fi connections… Keep your iPhone connected by USB and unlocked." : action == "reveal" ? "Revealing Developer Mode… Unlock your iPhone and accept any trust prompt." : (action == "set" ? "Connecting and setting location…" : "Restoring location…")
        DispatchQueue.global(qos: .userInitiated).async {
            if let old = previous, old.isRunning { old.terminate(); old.waitUntilExit() }
            let process = Process(); let pipe = Pipe(); let ready = ReadyFlag()
            process.executableURL = URL(fileURLWithPath: python); process.arguments = args
            var environment = ProcessInfo.processInfo.environment; environment["PYTHONUNBUFFERED"] = "1"; process.environment = environment
            process.standardOutput = pipe; process.standardError = pipe
            if persistent {
                process.terminationHandler = { ended in
                    DispatchQueue.main.async {
                        if self.activeSession === ended {
                            self.activeSession = nil
                            if self.running { self.stop() }
                            self.status = "Connection lost. The simulated location may have ended; reconnect and set it again."
                        }
                    }
                }
            }
            var output = ""; var ok = false
            do {
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 45) {
                    if process.isRunning && (!persistent || !ready.get()) { process.terminate() }
                }
                if persistent {
                    var data = Data()
                    while true {
                        let chunk = pipe.fileHandleForReading.readData(ofLength: 1)
                        if chunk.isEmpty { break }
                        data.append(chunk)
                        if let text = String(data: data, encoding: .utf8), text.contains("Press Ctrl+C to send a SIGINT") { ok = true; break }
                    }
                    output = String(data: data, encoding: .utf8) ?? ""
                    if ok { ready.set() } else { process.waitUntilExit() }
                } else {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit(); output = String(data: data, encoding: .utf8) ?? ""; ok = process.terminationStatus == 0
                }
            } catch { output = error.localizedDescription }
            DispatchQueue.main.async {
                if ok && persistent && process.isRunning { self.activeSession = process }
                else if ok && persistent { ok = false; output += "\nSession ended before it could be kept open." }
                self.busy = false; self.log = output.isEmpty ? "Command completed without additional output." : output
                if ok && action == "set", let p = point, !self.running { self.recordHistory(p) }
                self.status = ok ? (action == "wifi" ? "Wi-Fi connections enabled. Unplug USB, select Wi-Fi mode, then set the location again." : (action == "reveal" ? "Developer Mode switch revealed. Follow the steps above on your iPhone." : (action == "set" ? "Location set. You can choose another location." : "Restore command completed."))) : "Command failed or timed out. See details below."
                completion?(ok)
            }
        }
    }

    func addPoint() { if let p = selected { route.append(p); status = "Added waypoint \(route.count)." } else { status = "Enter valid coordinates." } }
    func stop() { timer?.invalidate(); timer = nil; running = false; status = "Movement stopped. The last simulated location remains active." }
    func start() {
        guard route.count >= 2 else { status = "Add at least two route points."; return }
        guard !busy else { return }
        running = true; targetIndex = 1; select(route[0], recenter: true)
        execute("set", point: route[0]) { ok in
            guard self.running else { return }
            guard ok else { self.running = false; return }
            self.lastTick = Date()
            self.timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in self.tick() }
        }
    }
    func tick() {
        guard running, !busy, let current = selected else { return }
        let target = route[targetIndex]
        let a = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let b = CLLocation(latitude: target.latitude, longitude: target.longitude)
        let distance = a.distance(from: b); let now = Date(); let travel = speed * max(0, now.timeIntervalSince(lastTick)); lastTick = now
        let f = distance == 0 ? 1 : min(1, travel / distance)
        let p = CLLocationCoordinate2D(latitude: current.latitude + (target.latitude-current.latitude)*f, longitude: current.longitude + (target.longitude-current.longitude)*f)
        select(p, recenter: true)
        execute("set", point: p) { ok in
            if !ok { self.stop(); return }
            if f >= 1 { self.targetIndex += 1; if self.targetIndex >= self.route.count { self.stop(); self.status = "Route complete. Restore location when finished." } }
        }
    }
    func move(_ north: Double, _ east: Double) {
        guard let p = selected, !running else { return }
        let lat = p.latitude + north * step / 111_320
        let cosLat = max(0.01, abs(cos(p.latitude * .pi / 180)))
        let lon = p.longitude + east * step / (111_320 * cosLat)
        guard abs(lat) <= 90, abs(lon) <= 180 else { status = "Movement exceeds coordinate limits."; return }
        let next = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        execute("set", point: next) { ok in if ok { self.select(next, recenter: true) } }
    }
}

let popularCities: [(String, Double, Double)] = [
    ("Tel Aviv", 32.0853, 34.7818), ("London", 51.5072, -0.1276), ("Paris", 48.8566, 2.3522),
    ("Berlin", 52.5200, 13.4050), ("Rome", 41.9028, 12.4964), ("Amsterdam", 52.3676, 4.9041),
    ("Barcelona", 41.3874, 2.1686), ("Lisbon", 38.7223, -9.1393), ("Prague", 50.0755, 14.4378),
    ("New York", 40.7128, -74.0060), ("Los Angeles", 34.0522, -118.2437), ("San Francisco", 37.7749, -122.4194),
    ("Chicago", 41.8781, -87.6298), ("Miami", 25.7617, -80.1918), ("Toronto", 43.6532, -79.3832),
    ("Vancouver", 49.2827, -123.1207), ("Mexico City", 19.4326, -99.1332)
]
struct Favorite: Codable, Identifiable {
    var id = UUID(); var name: String; var latitude: Double; var longitude: Double
}
final class GPXReader: NSObject, XMLParserDelegate {
    var points: [CLLocationCoordinate2D] = []
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String:String]) {
        guard ["rtept", "trkpt"].contains(name), let a = attributes["lat"], let b = attributes["lon"], let lat = Double(a), let lon = Double(b), lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180 else { return }
        points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
}

struct MapView: NSViewRepresentable {
    @EnvironmentObject var model: Model
    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView(); map.delegate = context.coordinator
        let click = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.clicked(_:)))
        map.addGestureRecognizer(click); map.setRegion(MKCoordinateRegion(center: model.center, latitudinalMeters: 10000, longitudinalMeters: 10000), animated: false)
        return map
    }
    func updateNSView(_ map: MKMapView, context: Context) {
        if context.coordinator.lastCenter.latitude != model.center.latitude || context.coordinator.lastCenter.longitude != model.center.longitude {
            map.setCenter(model.center, animated: true); context.coordinator.lastCenter = model.center
        }
        map.removeAnnotations(map.annotations); map.removeOverlays(map.overlays)
        if let p = model.selected { let pin = MKPointAnnotation(); pin.coordinate = p; pin.title = "Selected location"; map.addAnnotation(pin) }
        for (i,p) in model.route.enumerated() { let pin = MKPointAnnotation(); pin.coordinate = p; pin.title = "Waypoint \(i+1)"; map.addAnnotation(pin) }
        if model.route.count > 1 { map.addOverlay(MKPolyline(coordinates: model.route, count: model.route.count)) }
    }
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    class Coordinator: NSObject, MKMapViewDelegate {
        let model: Model; var lastCenter = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        init(_ model: Model) { self.model = model }
        @objc func clicked(_ gesture: NSClickGestureRecognizer) { guard let map = gesture.view as? MKMapView else { return }; model.select(map.convert(gesture.location(in: map), toCoordinateFrom: map)) }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer { let r = MKPolylineRenderer(overlay: overlay); r.strokeColor = .systemBlue; r.lineWidth = 3; return r }
    }
}

struct ContentView: View {
    @EnvironmentObject var m: Model
    var body: some View {
        HSplitView {
            MapView().frame(minWidth: 430)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Spoofy").font(.largeTitle.bold())
                    Text("Select a place on the map, or search for an address.").foregroundColor(.secondary)
                    HStack { TextField("Search for a place", text: $m.search).onSubmit { m.find() }; Button("Search") { m.find() } }
                    HStack { TextField("Latitude", text: $m.latitude); TextField("Longitude", text: $m.longitude) }
                    Toggle("iOS 17 or newer", isOn: $m.modern)
                    Toggle("Connect over Wi-Fi (experimental)", isOn: $m.wireless).disabled(m.busy || m.running)
                    Text("For Wi-Fi: connect by USB and unlock your iPhone, click Enable Wi-Fi below, then unplug USB and set the location again. Keep the Mac awake, Spoofy open, and both devices on the same network.").font(.caption).foregroundColor(.secondary)
                    GroupBox("iPhone setup") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("1. Connect and unlock your iPhone. Tap Trust if asked.")
                            Text("2. If Developer Mode is missing, click Reveal below.")
                            Text("3. On iPhone, open Settings → Privacy & Security → Developer Mode and turn it on.")
                            Text("4. Tap Restart, unlock your phone, then confirm Turn On and enter your passcode.")
                            Text("Developer Mode reduces some device security protections. You can turn it off later in Settings.").foregroundColor(.secondary)
                            Button("Reveal Developer Mode") { m.execute("reveal") }.disabled(m.busy || m.running)
                            Button("Enable Wi-Fi connections") { m.execute("wifi") }.disabled(m.busy || m.running)
                        }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack { Button("Set location") { m.execute("set", point: m.selected) }.disabled(m.busy || m.running); Button("Restore real location") { m.stop(); m.execute("clear") }.disabled(m.busy) }
                    Divider()
                    Text("Popular cities").font(.headline)
                    Menu("Choose a city") {
                        ForEach(popularCities, id: \.0) { city in
                            Button(city.0) { m.search = city.0; m.select(CLLocationCoordinate2D(latitude: city.1, longitude: city.2), recenter: true) }
                        }
                    }
                    Text("Recent locations").font(.headline)
                    if m.history.isEmpty { Text("Locations you set appear here.").font(.caption).foregroundColor(.secondary) }
                    ForEach(m.history) { item in
                        Button(item.name) { m.select(CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude), recenter: true) }
                    }
                    if !m.history.isEmpty { Button("Clear history") { m.clearHistory() } }
                    Divider()
                    Text("Saved locations").font(.headline)
                    Button("Save selected location") { m.saveFavorite() }
                    ForEach(m.favorites) { item in
                        HStack {
                            Button(item.name) { m.select(CLLocationCoordinate2D(latitude: item.latitude, longitude: item.longitude), recenter: true) }
                            Spacer()
                            Button("Remove") { m.deleteFavorite(item.id) }
                        }
                    }
                    Divider()
                    Text("Route").font(.headline)
                    Text("Select each waypoint on the map and add it. Add waypoints, or import GPX. Choose Follow roads for walking directions.").font(.caption).foregroundColor(.secondary)
                    HStack { Button("Add waypoint") { m.addPoint() }.disabled(m.running); Button("Clear route") { m.route.removeAll() }.disabled(m.running); Text("\(m.route.count) points") }
                    HStack { Button("Follow roads") { m.followRoads() }.disabled(m.running || m.busy); Button("Import GPX") { m.importGPX() }.disabled(m.running || m.busy); Button("Export GPX") { m.exportGPX() }.disabled(m.busy) }
                    HStack { Text("Speed: \(m.speed, specifier: "%.1f") m/s"); Slider(value: $m.speed, in: 1...30) }
                    HStack { Button("Start route") { m.start() }.disabled(m.running || m.busy); Button("Stop movement") { m.stop() }.disabled(!m.running) }
                    Divider()
                    Text("Move from selected location").font(.headline)
                    HStack { Text("Step: \(Int(m.step)) m"); Slider(value: $m.step, in: 10...500, step: 10) }
                    HStack { Button("←") { m.move(0, -1) }; Button("↑") { m.move(1, 0) }; Button("↓") { m.move(-1, 0) }; Button("→") { m.move(0, 1) } }.disabled(m.busy || m.running)
                    Divider()
                    Text(m.status).font(.callout)
                    ScrollView { Text(m.log).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(minHeight: 65, maxHeight: 130)
                }.padding(18)
            }.frame(minWidth: 380, idealWidth: 430)
        }
    }
}
