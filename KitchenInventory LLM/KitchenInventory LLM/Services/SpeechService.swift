//
//  SpeechService.swift
//  KitchenInventory LLM
//
//  Created by Angel on 4/2/26.
//

import AVFoundation
import os
import Speech

/// Actor wrapping SFSpeechRecognizer + AVAudioEngine for streaming voice-to-text.
/// On-device recognition preferred; falls back to server-based if unavailable.
actor SpeechService {
    // MARK: - State

    enum RecordingState: Sendable {
        case idle
        case recording
        case stopping
    }

    private(set) var state: RecordingState = .idle

    // MARK: - Speech Stack

    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // MARK: - Configuration

    /// Seconds of silence AFTER first speech detected before auto-stop
    let silenceTimeout: TimeInterval

    /// Seconds to wait for first speech before giving up
    let initialTimeout: TimeInterval

    // MARK: - Init

    init(locale: Locale = .current, silenceTimeout: TimeInterval = 2.5, initialTimeout: TimeInterval = 8.0) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        self.silenceTimeout = silenceTimeout
        self.initialTimeout = initialTimeout
    }

    // MARK: - Permissions

    /// Requests both microphone and speech recognition authorization.
    /// Returns `true` only if both are granted.
    func requestPermissions() async -> Bool {
        let micGranted = await AVAudioApplication.requestRecordPermission()

        guard micGranted else { return false }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        return speechStatus == .authorized
    }

    /// Checks current authorization without prompting.
    /// Returns simple bools so callers don't need AVFAudio/Speech imports.
    nonisolated func isFullyAuthorized() -> (microphoneGranted: Bool, speechAuthorized: Bool) {
        let micGranted = AVAudioApplication.shared.recordPermission == .granted
        let speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        return (micGranted, speechGranted)
    }

    // MARK: - Start Listening

    /// Starts recording and returns an `AsyncStream` of partial transcription strings.
    /// The stream completes when recording stops (manually or via silence timeout).
    func startListening() async throws -> AsyncStream<String> {
        guard state == .idle else {
            print("[SpeechService] Cannot start: state is \(state), not idle")
            throw KitchenError.speechUnavailable
        }

        guard speechRecognizer.isAvailable else {
            print("[SpeechService] Speech recognizer not available")
            throw KitchenError.speechUnavailable
        }

        // Check permissions
        let (micGranted, speechGranted) = isFullyAuthorized()
        guard micGranted else {
            print("[SpeechService] Microphone not granted")
            throw KitchenError.microphoneDenied
        }
        guard speechGranted else {
            print("[SpeechService] Speech recognition not authorized")
            throw KitchenError.speechUnavailable
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Prefer on-device but DON'T require it — fall back to server-based if unavailable
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false // prefer but don't require
            print("[SpeechService] On-device recognition available, will prefer it")
        } else {
            print("[SpeechService] On-device recognition NOT available, using server-based")
        }

        self.recognitionRequest = request
        state = .recording

        // Install audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        print("[SpeechService] Audio engine started, listening...")

        // Build the stream
        let silenceTime = self.silenceTimeout
        let initialTime = self.initialTimeout
        let timerLock = OSAllocatedUnfairLock<DispatchWorkItem?>(initialState: nil)
        let timerQueue = DispatchQueue(label: "com.kitcheninventory.silence-timer")
        let hasReceivedSpeech = OSAllocatedUnfairLock<Bool>(initialState: false)

        // Sendable helpers that capture only Sendable values
        let scheduleTimeout: @Sendable (_ duration: TimeInterval) -> Void = { [weak request] duration in
            timerLock.withLock { $0?.cancel() }
            let work = DispatchWorkItem { [weak request] in
                print("[SpeechService] Silence timeout fired (\(duration)s)")
                request?.endAudio()
            }
            timerLock.withLock { $0 = work }
            timerQueue.asyncAfter(deadline: .now() + duration, execute: work)
        }

        let cancelTimeout: @Sendable () -> Void = {
            timerLock.withLock { timer in
                timer?.cancel()
                timer = nil
            }
        }

        let stream = AsyncStream<String> { continuation in
            // Schedule INITIAL timeout — generous, gives user time to start speaking
            // and gives the recognizer time to warm up
            scheduleTimeout(initialTime)

            self.recognitionTask = self.speechRecognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    print("[SpeechService] Transcript: \"\(transcript)\" (final: \(result.isFinal))")
                    continuation.yield(transcript)

                    // Mark that we've received speech
                    hasReceivedSpeech.withLock { $0 = true }

                    if result.isFinal {
                        cancelTimeout()
                        continuation.finish()
                    } else {
                        // After first speech, use the shorter silence timeout
                        scheduleTimeout(silenceTime)
                    }
                }

                if let error = error {
                    print("[SpeechService] Recognition error: \(error.localizedDescription)")
                    cancelTimeout()
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in
                cancelTimeout()
            }
        }

        return stream
    }

    // MARK: - Stop Listening

    /// Stops the current recording session. Safe to call even if not recording.
    func stopListening() {
        guard state == .recording else { return }
        state = .stopping
        print("[SpeechService] Stopping...")

        recognitionRequest?.endAudio()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        // Deactivate audio session to release audio focus
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        state = .idle
        print("[SpeechService] Stopped, state = idle")
    }

    // MARK: - Cleanup

    /// Force cleanup — call when the view disappears.
    func teardown() {
        stopListening()
    }
}
