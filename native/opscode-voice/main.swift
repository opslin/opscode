// opscode-voice: Opscode's microphone helper. Records the Mac's microphone and turns speech into text with
// Apple's on-device recognizer (SpeechAnalyzer + SpeechTranscriber, macOS 26). Nothing leaves the Mac.
// Protocol: one JSON object per line. Commands on stdin, events on stdout.
//   {"cmd":"status"}                      -> {"ev":"status","available":true,"mic":"granted|denied|undetermined|restricted","os":"26.2"}
//   {"cmd":"locales"}                     -> {"ev":"locales","speech":[...],"dictation":[...],"installed":[...]}
//   {"cmd":"start","locale":"en-US","record":"/abs/file.m4a"?,"words":["Opscode",...]?}
//        -> {"ev":"asset","progress":0.4}* {"ev":"started","locale":..,"engine":"speech|dictation"}
//           {"ev":"level","rms":0.12}* {"ev":"partial","text":..}* {"ev":"final","text":..}*
//   {"cmd":"stop"}                        -> {"ev":"done","text":full,"file":path?,"secs":n}
//   {"cmd":"cancel"}                      -> {"ev":"cancelled"}
//   {"cmd":"file","path":"/abs/a.m4a","locale":"en-US"} -> partial/final ... {"ev":"done","text":..,"secs":n}
//   errors                                -> {"ev":"error","code":"mic_denied|unavailable|locale|asset|audio|busy|bad_command","message":..}
// Exits when stdin closes.

import AVFoundation
import Foundation
import CoreMedia
import Speech

let out = FileHandle.standardOutput
let outLock = NSLock()
func emit(_ obj: [String: Any]) {
  guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []) else { return }
  outLock.lock(); defer { outLock.unlock() }
  out.write(data); out.write("\n".data(using: .utf8)!)
}
func fail(_ code: String, _ message: String) { emit(["ev": "error", "code": code, "message": message]) }

func micState() -> String {
  switch AVCaptureDevice.authorizationStatus(for: .audio) {
  case .authorized: return "granted"
  case .denied: return "denied"
  case .restricted: return "restricted"
  default: return "undetermined"
  }
}

func askMic() async -> Bool {
  switch AVCaptureDevice.authorizationStatus(for: .audio) {
  case .authorized: return true
  case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
  default: return false
  }
}

@available(macOS 26.0, *)
final class Session: @unchecked Sendable {
  let analyzer: SpeechAnalyzer
  let module: any SpeechModule
  let builder: AsyncStream<AnalyzerInput>.Continuation
  let format: AVAudioFormat
  var engine: AVAudioEngine?
  var file: AVAudioFile?
  var filePath: String?
  var converter: AVAudioConverter?
  var finalText = ""
  var resultsTask: Task<Void, Never>?
  var started = Date()
  var lastLevel = Date.distantPast
  /** Conversation mode: results go here instead of being emitted as partial/final lines. */
  var onResult: (@Sendable (String, Bool, Double, Double) -> Void)?

  init(analyzer: SpeechAnalyzer, module: any SpeechModule, builder: AsyncStream<AnalyzerInput>.Continuation, format: AVAudioFormat) {
    self.analyzer = analyzer; self.module = module; self.builder = builder; self.format = format
  }

  /** Converts a buffer to the analyzer's format and feeds it. */
  func feed(_ buffer: AVAudioPCMBuffer, at: Double? = nil) {
    let stamp: CMTime? = at.map { CMTime(seconds: $0, preferredTimescale: 16000) }
    if buffer.format == format { builder.yield(AnalyzerInput(buffer: buffer, bufferStartTime: stamp)); return }
    if converter == nil || converter!.inputFormat != buffer.format { converter = AVAudioConverter(from: buffer.format, to: format) }
    guard let conv = converter else { return }
    let ratio = format.sampleRate / buffer.format.sampleRate
    let cap = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
    guard let outBuf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: cap) else { return }
    var used = false
    var err: NSError?
    conv.convert(to: outBuf, error: &err) { _, status in
      if used { status.pointee = .noDataNow; return nil }
      used = true; status.pointee = .haveData; return buffer
    }
    if err == nil && outBuf.frameLength > 0 { builder.yield(AnalyzerInput(buffer: outBuf, bufferStartTime: stamp)) }
  }

  func level(_ buffer: AVAudioPCMBuffer) {
    let now = Date()
    guard now.timeIntervalSince(lastLevel) >= 0.08, let ch = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
    lastLevel = now
    var sum: Float = 0
    for i in 0..<Int(buffer.frameLength) { sum += ch[i] * ch[i] }
    let rms = sqrt(sum / Float(buffer.frameLength))
    emit(["ev": "level", "rms": Double(min(1, rms * 4))])
  }
}

@available(macOS 26.0, *)
func pickModule(_ wanted: Locale, words: [String]) async -> (any SpeechModule, String, Locale)? {
  if SpeechTranscriber.isAvailable, let loc = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) {
    return (SpeechTranscriber(locale: loc, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: []), "speech", loc)
  }
  if let loc = await DictationTranscriber.supportedLocale(equivalentTo: wanted) {
    return (DictationTranscriber(locale: loc, contentHints: [], transcriptionOptions: [.punctuation], reportingOptions: [.volatileResults], attributeOptions: []), "dictation", loc)
  }
  return nil
}

@available(macOS 26.0, *)
func results(of module: any SpeechModule, into s: Session) -> Task<Void, Never> {
  Task {
    do {
      if let t = module as? SpeechTranscriber {
        for try await r in t.results { handle(String(r.text.characters), final: r.isFinal, s, start: r.range.start.seconds, end: r.range.end.seconds) }
      } else if let d = module as? DictationTranscriber {
        for try await r in d.results { handle(String(r.text.characters), final: r.isFinal, s, start: r.range.start.seconds, end: r.range.end.seconds) }
      }
    } catch { fail("audio", "recognition stopped: \(error.localizedDescription)") }
  }
}

@available(macOS 26.0, *)
func handle(_ text: String, final: Bool, _ s: Session, start: Double = 0, end: Double = 0) {
  if let cb = s.onResult { cb(text, final, start, end); return }
  if final {
    let piece = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !piece.isEmpty { s.finalText += (s.finalText.isEmpty ? "" : " ") + piece }
    emit(["ev": "final", "text": piece, "full": s.finalText])
  } else {
    emit(["ev": "partial", "text": text])
  }
}

/** Builds an analyzer for the locale, downloading Apple's language model once if needed. */
@available(macOS 26.0, *)
func makeSession(locale: String, words: [String]) async -> Session? {
  // "auto": the Mac's own language and region (an Indian English Mac gets en-IN).
  let wanted = locale == "auto" || locale.isEmpty ? Locale.current : Locale(identifier: locale)
  guard let (module, engineName, loc) = await pickModule(wanted, words: words) else {
    fail("locale", "On-device speech recognition does not support \(locale) on this Mac."); return nil
  }
  do {
    if let req = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
      let p = req.progress
      let watch = Task { while !Task.isCancelled { emit(["ev": "asset", "progress": p.fractionCompleted]); try? await Task.sleep(nanoseconds: 400_000_000) } }
      try await req.downloadAndInstall()
      watch.cancel()
      emit(["ev": "asset", "progress": 1.0])
    }
  } catch { fail("asset", "Could not get Apple's speech model for \(loc.identifier): \(error.localizedDescription)"); return nil }
  guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else { fail("audio", "No audio format for the recognizer"); return nil }
  let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
  let analyzer = SpeechAnalyzer(modules: [module])
  if !words.isEmpty {
    let ctx = AnalysisContext()
    ctx.contextualStrings = [.general: Array(words.prefix(100))]
    try? await analyzer.setContext(ctx)
  }
  let s = Session(analyzer: analyzer, module: module, builder: builder, format: format)
  s.resultsTask = results(of: module, into: s)
  do { try await analyzer.start(inputSequence: stream) } catch { fail("audio", "Could not start the recognizer: \(error.localizedDescription)"); return nil }
  emit(["ev": "started", "locale": loc.identifier, "engine": engineName])
  return s
}

@available(macOS 26.0, *)
func finish(_ s: Session) async -> String {
  s.builder.finish()
  do { try await s.analyzer.finalizeAndFinishThroughEndOfInput() } catch { fail("audio", "finishing: \(error.localizedDescription)") }
  await s.resultsTask?.value
  return s.finalText
}

/// Conversation mode. Audio comes from the window as {"cmd":"audio","pcm":base64 of Int16 little-endian, mono, 16 kHz}
/// (the window's microphone, after Chromium's echo cancellation). A simple energy detector with an adaptive noise floor
/// cuts the stream into utterances; the recognizer finalizes each one and it is reported as {"ev":"utterance"}.
/// Time is the audio clock (samples received), so a file fed in as fast as it can be read behaves like a live microphone.
@available(macOS 26.0, *)
final class Converse: @unchecked Sendable {
  let s: Session
  let lock = NSLock()
  let fmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
  static let rate = 16000
  static let frame = 320 // 20 ms
  let endSamples: Int
  let speechSamples: Int
  let maxSamples = 60 * 16000
  var boost = 1.0
  var floor = 0.004
  var carry = [Int16]()
  var vadT = 0 // samples the detector has looked at
  var speaking = false
  var voicedRun = 0
  var lastVoiced = 0
  var startAt = 0
  var finalizing = false
  var closed = false
  struct Piece { var text: String; var start: Double; var end: Double }
  var finals = [Piece]()      // finished pieces not yet handed out, with the audio time they cover
  var vol: Piece?             // the recognizer's current guess for what is being said
  var lastResult = Date.distantPast
  var lastPartial = ""
  var lastPartialAt = Date.distantPast

  init(_ s: Session, endMs: Int, speechMs: Int) {
    self.s = s
    self.endSamples = endMs * Converse.rate / 1000
    self.speechSamples = speechMs * Converse.rate / 1000
    s.onResult = { [weak self] text, final, start, end in self?.result(text, final, start, end) }
  }

  /** Leading marks the recognizer leaves behind ("..,") are not words. */
  static func clean(_ t: String) -> String {
    let t = t.trimmingCharacters(in: .whitespacesAndNewlines)
    let marks = CharacterSet(charactersIn: " \n\t,.;:!?…-–—")
    var scalars = Substring(t).unicodeScalars
    while let f = scalars.first, marks.contains(f) { scalars.removeFirst() }
    let out = String(scalars)
    if out.rangeOfCharacter(from: .alphanumerics) == nil { return "" }
    return out.prefix(1).uppercased() + out.dropFirst()
  }

  /** What has been heard and not handed out; `cut` (seconds of audio) leaves out what came after it. */
  func joined(cut: Double? = nil) -> String {
    var parts = [String]()
    for p in finals where cut == nil || p.end <= cut! + 0.3 { parts.append(p.text) }
    if let v = vol, cut == nil || v.end <= cut! + 0.3 { parts.append(v.text) }
    return Converse.clean(parts.joined(separator: " "))
  }

  static let debug = ProcessInfo.processInfo.environment["OPSCODE_VOICE_DEBUG"] != nil
  func result(_ text: String, _ final: Bool, _ start: Double, _ end: Double) {
    lock.lock(); defer { lock.unlock() }
    lastResult = Date()
    if Converse.debug { emit(["ev": "debug", "what": "result", "final": final, "text": text, "start": start, "end": end, "vadT": Double(vadT) / 16000.0]) }
    if final {
      let piece = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if !piece.isEmpty { finals.append(Piece(text: piece, start: start, end: end)) }
      if let v = vol, v.start < end { vol = nil }
    } else { vol = Piece(text: text, start: start, end: end) }
    let now = Date()
    let t = joined()
    if !t.isEmpty, t != lastPartial, now.timeIntervalSince(lastPartialAt) >= 0.12 {
      lastPartial = t; lastPartialAt = now
      emit(["ev": "partial", "text": t])
    }
  }

  func setBoost(_ b: Double) { lock.lock(); boost = max(1.0, min(6.0, b)); lock.unlock() }

  // The recognizer only hears speech. Audio is fed to it half a second late; what lies outside a detected speech
  // interval is replaced by silence (same length, so its timeline stays unbroken). A click, a fan or music below
  // the detector's threshold never reaches it, and the first words are not clipped (the lag is the pre-roll).
  var ring = [Int16]()
  var rx = 0            // samples received so far
  var fedUpTo = 0       // samples handed to the recognizer so far
  var opens = [(from: Int, to: Int)]() // speech intervals; `to` is Int.max while the speaker is still going
  static let lag = 8000 // 0.5 s

  /** Takes a chunk of audio: runs the detector and feeds the recognizer. */
  func push(_ bytes: [UInt8]) {
    lock.lock()
    if closed { lock.unlock(); return }
    var fresh = [Int16]()
    fresh.reserveCapacity(bytes.count / 2)
    var i = 0
    while i + 1 < bytes.count { fresh.append(Int16(bitPattern: UInt16(bytes[i]) | (UInt16(bytes[i + 1]) << 8))); i += 2 }
    ring.append(contentsOf: fresh)
    rx += fresh.count
    let work = carry + fresh
    let frame = Converse.frame
    var idx = 0
    var wake = false
    while idx + frame <= work.count {
      var sum = 0.0
      for k in idx..<(idx + frame) { let v = Double(work[k]) / 32768.0; sum += v * v }
      if detect((sum / Double(frame)).squareRoot()) { wake = true }
      idx += frame
    }
    carry = Array(work[idx...])
    feed(upTo: rx - Converse.lag)
    lock.unlock()
    if wake { Task.detached { [self] in await endpoint() } }
  }

  /** Hands the recognizer the audio before `target` that it has not had yet, silence where nobody spoke (lock held). */
  func feed(upTo target: Int) {
    let n = target - fedUpTo
    guard n > 0 else { return }
    let base = rx - ring.count // sample index of ring[0]
    if let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n)) {
      buf.frameLength = AVAudioFrameCount(n)
      let dst = buf.int16ChannelData![0]
      for k in 0..<n {
        let at = fedUpTo + k
        var open = false
        for o in opens where at >= o.from && at < o.to { open = true; break }
        let r = at - base
        dst[k] = open && r >= 0 && r < ring.count ? ring[r] : 0
      }
      s.feed(buf)
    }
    fedUpTo = target
    opens.removeAll { $0.to <= fedUpTo }
    let drop = fedUpTo - base
    if drop > 0 { ring.removeFirst(min(drop, ring.count)) }
  }

  /** One 20 ms frame. Returns true when the utterance has ended and must be finalized. */
  func detect(_ rms: Double) -> Bool {
    let base = max(0.010, floor * 3.0) * boost
    let voiced = rms > (speaking ? base * 0.6 : base)
    var end = false
    if !speaking {
      if !voiced { floor = min(0.03, max(0.0015, floor * 0.97 + rms * 0.03)) }
      if voiced {
        voicedRun += Converse.frame
        if voicedRun >= speechSamples { speaking = true; startAt = vadT - voicedRun; lastVoiced = vadT; opens.append((from: max(fedUpTo, startAt - 3200), to: Int.max)); emit(["ev": "speech"]) }
      } else { voicedRun = 0 }
    } else {
      if voiced { lastVoiced = vadT }
      if !finalizing && (vadT - lastVoiced >= endSamples || vadT - startAt >= maxSamples) { finalizing = true; end = true }
    }
    vadT += Converse.frame
    return end
  }

  // Locking is kept in plain (non-async) methods: NSLock must not be held across a suspension point.
  func isQuiet() -> Bool { lock.lock(); defer { lock.unlock() }; return Date().timeIntervalSince(lastResult) >= 0.15 }
  /** Hands out what was heard up to `cut` seconds of audio (all of it for nil); the rest stays for the next utterance. */
  func takeText(cut: Double?, resetDetector: Bool) -> (String, Int) {
    lock.lock(); defer { lock.unlock() }
    let text = joined(cut: cut)
    var keep = [Piece]()
    for p in finals where !(cut == nil || p.end <= cut! + 0.3) { keep.append(p) }
    finals = keep
    if let v = vol, cut == nil || v.end <= cut! + 0.3 { vol = nil }
    lastPartial = ""
    let ms = max(0, (lastVoiced - startAt) * 1000 / Converse.rate)
    if resetDetector { speaking = false; voicedRun = 0; finalizing = false; for k in 0..<opens.count where opens[k].to == Int.max { opens[k].to = vadT } }
    return (text, ms)
  }
  func close() { lock.lock(); closed = true; lock.unlock() }
  func flush() { lock.lock(); feed(upTo: rx); lock.unlock() }
  func cutoff() -> Double { lock.lock(); defer { lock.unlock() }; return Double(lastVoiced) / Double(Converse.rate) + 0.4 }

  func endpoint() async {
    // Finalize through where the speech ended (a little after it), not through everything received: audio that
    // arrived while this runs belongs to the next utterance.
    let cut = cutoff()
    try? await s.analyzer.finalize(through: CMTime(seconds: cut, preferredTimescale: 1000))
    try? await Task.sleep(nanoseconds: 120_000_000)
    // Wait until the recognizer has stopped delivering results (at most 0.8 s).
    let deadline = Date().addingTimeInterval(0.8)
    while Date() < deadline {
      if isQuiet() { break }
      try? await Task.sleep(nanoseconds: 40_000_000)
    }
    let (text, ms) = takeText(cut: cut, resetDetector: true)
    if Converse.debug { emit(["ev": "debug", "what": "endpoint", "cut": cut, "text": text]) }
    if text.isEmpty { emit(["ev": "noise", "ms": ms]) } else { emit(["ev": "utterance", "text": text, "ms": ms]) }
  }

  /** Ends the session. Whatever was being said and not yet reported comes out as a last utterance. */
  func stop(cancel: Bool) async -> String {
    close()
    if !cancel { flush() }
    s.builder.finish()
    if cancel { await s.analyzer.cancelAndFinishNow(); return "" }
    do { try await s.analyzer.finalizeAndFinishThroughEndOfInput() } catch { /* nothing more to finalize */ }
    await s.resultsTask?.value
    return takeText(cut: nil, resetDetector: false).0
  }
}

// The running conversation, reachable without going through the Voice actor (audio arrives ten times a second).
let convRefLock = NSLock()
nonisolated(unsafe) var convRef: AnyObject?
func setConvRef(_ c: AnyObject?) { convRefLock.lock(); convRef = c; convRefLock.unlock() }
func getConvRef() -> AnyObject? { convRefLock.lock(); defer { convRefLock.unlock() }; return convRef }

@available(macOS 26.0, *)
actor Voice {
  var session: Session?
  var conv: Converse?

  func converse(locale: String, words: [String], endMs: Int, speechMs: Int) async {
    if session != nil || conv != nil { fail("busy", "Already listening"); return }
    // No microphone here: the window captures it (Chromium echo cancellation) and sends the audio.
    guard let s = await makeSession(locale: locale, words: words) else { return }
    let c = Converse(s, endMs: endMs, speechMs: speechMs)
    conv = c
    setConvRef(c)
    s.started = Date()
  }

  func start(locale: String, record: String?, words: [String]) async {
    if session != nil { fail("busy", "Already listening"); return }
    guard await askMic() else { fail("mic_denied", "Opscode may not use the microphone. Allow it in System Settings > Privacy & Security > Microphone."); return }
    guard let s = await makeSession(locale: locale, words: words) else { return }
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let inFormat = input.outputFormat(forBus: 0)
    guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else { fail("audio", "No microphone input on this Mac"); await s.analyzer.cancelAndFinishNow(); return }
    if let path = record {
      do {
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: inFormat.sampleRate, AVNumberOfChannelsKey: min(2, Int(inFormat.channelCount)), AVEncoderBitRateKey: 96_000]
        s.file = try AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        s.filePath = path
      } catch { fail("audio", "Could not create the recording file: \(error.localizedDescription)") }
    }
    input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { buffer, _ in
      s.level(buffer)
      s.feed(buffer)
      if let f = s.file { try? f.write(from: buffer) }
    }
    do { engine.prepare(); try engine.start() } catch {
      input.removeTap(onBus: 0)
      fail("audio", "Could not start the microphone: \(error.localizedDescription)")
      await s.analyzer.cancelAndFinishNow()
      return
    }
    s.engine = engine
    s.started = Date()
    session = s
  }

  func stop(cancel: Bool) async {
    if let c = conv {
      conv = nil
      setConvRef(nil)
      let secs = Date().timeIntervalSince(c.s.started)
      let text = await c.stop(cancel: cancel)
      if cancel { emit(["ev": "cancelled"]) } else { emit(["ev": "done", "text": text, "secs": secs]) }
      return
    }
    guard let s = session else { emit(["ev": cancel ? "cancelled" : "done", "text": ""]); return }
    session = nil
    s.engine?.inputNode.removeTap(onBus: 0)
    s.engine?.stop()
    let secs = Date().timeIntervalSince(s.started)
    s.file = nil // closes the file
    if cancel {
      await s.analyzer.cancelAndFinishNow()
      if let p = s.filePath { try? FileManager.default.removeItem(atPath: p) }
      emit(["ev": "cancelled"])
      return
    }
    let text = await finish(s)
    var done: [String: Any] = ["ev": "done", "text": text, "secs": secs]
    if let p = s.filePath { done["file"] = p }
    emit(done)
  }

  func file(path: String, locale: String, words: [String]) async {
    if session != nil { fail("busy", "Already listening"); return }
    let url = URL(fileURLWithPath: path)
    guard let audio = try? AVAudioFile(forReading: url) else { fail("audio", "Could not read \(path)"); return }
    guard let s = await makeSession(locale: locale, words: words) else { return }
    let started = Date()
    let chunk: AVAudioFrameCount = 16_384
    while true {
      guard let buf = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: chunk) else { break }
      do { try audio.read(into: buf, frameCount: chunk) } catch { break }
      if buf.frameLength == 0 { break }
      s.feed(buf)
    }
    let text = await finish(s)
    emit(["ev": "done", "text": text, "secs": Double(audio.length) / audio.processingFormat.sampleRate, "took": Date().timeIntervalSince(started)])
  }
}

func locales() async {
  if #available(macOS 26.0, *) {
    let speech = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
    let dict = await DictationTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
    let inst = await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) }
    emit(["ev": "locales", "speech": speech.sorted(), "dictation": dict.sorted(), "installed": inst.sorted()])
  } else { emit(["ev": "locales", "speech": [], "dictation": [], "installed": []]) }
}

func status() {
  var available = false
  if #available(macOS 26.0, *) { available = SpeechTranscriber.isAvailable }
  let v = ProcessInfo.processInfo.operatingSystemVersion
  emit(["ev": "status", "available": available, "mic": micState(), "os": "\(v.majorVersion).\(v.minorVersion)"])
}

// ---- main loop: read commands until stdin closes ----------------------------------------------------------------
func serve() async {
  emit(["ev": "ready"])
  var voiceBox: AnyObject? = nil
  if #available(macOS 26.0, *) { voiceBox = Voice() }
  do {
    for try await line in FileHandle.standardInput.bytes.lines {
      guard let data = line.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let cmd = obj["cmd"] as? String else {
        fail("bad_command", "not a JSON command"); continue
      }
      let locale = (obj["locale"] as? String) ?? "en-US"
      let words = (obj["words"] as? [String]) ?? []
      switch cmd {
      case "status": status()
      case "locales": await locales()
      case "audio":
        // Conversation audio: base64 of Int16 LE mono 16 kHz. Not awaited: it only feeds buffers.
        if #available(macOS 26.0, *), let c = getConvRef() as? Converse, let b64 = obj["pcm"] as? String, let d = Data(base64Encoded: b64) { c.push([UInt8](d)) }
      case "vad":
        if #available(macOS 26.0, *), let c = getConvRef() as? Converse, let b = obj["boost"] as? Double { c.setBoost(b) }
      case "start", "stop", "cancel", "file", "converse":
        guard #available(macOS 26.0, *), let voice = voiceBox as? Voice else { fail("unavailable", "Needs macOS 26 or later"); continue }
        switch cmd {
        case "converse": await voice.converse(locale: locale, words: words, endMs: (obj["end_ms"] as? Int) ?? 1100, speechMs: (obj["speech_ms"] as? Int) ?? 240)
        case "start": await voice.start(locale: locale, record: obj["record"] as? String, words: words)
        case "stop": await voice.stop(cancel: false)
        case "cancel": await voice.stop(cancel: true)
        default:
          if let p = obj["path"] as? String { await voice.file(path: p, locale: locale, words: words) } else { fail("bad_command", "file needs path") }
        }
      default: fail("bad_command", "unknown command \(cmd)")
      }
    }
  } catch { fail("bad_command", "stdin: \(error.localizedDescription)") }
  if #available(macOS 26.0, *), let voice = voiceBox as? Voice { await voice.stop(cancel: true) }
  exit(0)
}

Task.detached { await serve() }
dispatchMain()
