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

    /// Seconds of silence before auto-stop
    let silenceTimeout: TimeInterval

    // MARK: - Init

    init(locale: Locale = .current, silenceTimeout: TimeInterval = 2.0) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        self.silenceTimeout = silenceTimeout
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
            throw KitchenError.speechUnavailable
        }

        guard speechRecognizer.isAvailable else {
            throw KitchenError.speechUnavailable
        }

        // Check permissions
        let (micGranted, speechGranted) = isFullyAuthorized()
        guard micGranted else {
            throw KitchenError.microphoneDenied
        }
        guard speechGranted else {
            throw KitchenError.speechUnavailable
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Prefer on-device when available
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
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

        // Build the stream
        let timeout = self.silenceTimeout
        let timerLock = OSAllocatedUnfairLock<DispatchWorkItem?>(initialState: nil)
        let timerQueue = DispatchQueue(label: "com.kitcheninventory.silence-timer")

        // Sendable helpers that capture only Sendable values
        let scheduleTimeout: @Sendable () -> Void = { [weak request] in
            timerLock.withLock { $0?.cancel() }
            let work = DispatchWorkItem { [weak request] in
                request?.endAudio()
            }
            timerLock.withLock { $0 = work }
            timerQueue.asyncAfter(deadline: .now() + timeout, execute: work)
        }

        let cancelTimeout: @Sendable () -> Void = {
            timerLock.withLock { timer in
                timer?.cancel()
                timer = nil
            }
        }

        let stream = AsyncStream<String> { continuation in
            // Schedule initial silence timeout
            scheduleTimeout()

            self.recognitionTask = self.speechRecognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    continuation.yield(transcript)

                    if result.isFinal {
                        cancelTimeout()
                        continuation.finish()
                    } else {
                        // Reset silence timer on each partial result
                        scheduleTimeout()
                    }
                }

                if error != nil {
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

        recognitionRequest?.endAudio()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        // Deactivate audio session to release audio focus
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        state = .idle
    }

    // MARK: - Cleanup

    /// Force cleanup — call when the view disappears.
    func teardown() {
        stopListening()
    }
}
