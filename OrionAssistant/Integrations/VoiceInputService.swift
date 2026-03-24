import AVFoundation
import Foundation
import Speech

protocol VoiceInputService {
    func requestPermissions() async throws -> VoicePermissionSummary
    func startRecognition(onUpdate: @escaping @Sendable (_ transcript: String, _ levels: [Double]) -> Void) async throws
    func stopRecognition() async throws -> String
}

actor MockVoiceInputService: VoiceInputService {
    private var finalTranscript = "帮我把明天下午三点到五点的产品评审加进日历，并提前三十分钟提醒我。"

    func requestPermissions() async throws -> VoicePermissionSummary {
        VoicePermissionSummary(microphoneGranted: true, speechRecognitionGranted: true)
    }

    func startRecognition(onUpdate: @escaping @Sendable (_ transcript: String, _ levels: [Double]) -> Void) async throws {
        let partials = [
            "帮我把明天下午三点",
            "帮我把明天下午三点到五点的产品评审",
            "帮我把明天下午三点到五点的产品评审加进日历",
            "帮我把明天下午三点到五点的产品评审加进日历，并提前三十分钟提醒我"
        ]

        for partial in partials {
            try await Task.sleep(nanoseconds: 180_000_000)
            onUpdate(partial, randomLevels())
        }
    }

    func stopRecognition() async throws -> String {
        try await Task.sleep(nanoseconds: 120_000_000)
        return finalTranscript
    }

    private func randomLevels() -> [Double] {
        (0..<6).map { _ in Double.random(in: 0.18...0.82) }
    }
}

final class SystemVoiceInputService: NSObject, VoiceInputService {
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var updateHandler: (@Sendable (_ transcript: String, _ levels: [Double]) -> Void)?

    func requestPermissions() async throws -> VoicePermissionSummary {
        let microphoneGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        return VoicePermissionSummary(
            microphoneGranted: microphoneGranted,
            speechRecognitionGranted: speechGranted
        )
    }

    func startRecognition(onUpdate: @escaping @Sendable (_ transcript: String, _ levels: [Double]) -> Void) async throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceInputError.recognizerUnavailable
        }

        stopEngineIfNeeded()
        updateHandler = onUpdate
        latestTranscript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 18.0, *) {
            request.addsPunctuation = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            self.updateHandler?(self.latestTranscript, self.meterLevels(from: buffer))
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.latestTranscript = result.bestTranscription.formattedString
                self.updateHandler?(self.latestTranscript, [0.22, 0.41, 0.36, 0.54, 0.29, 0.46])
            }

            if error != nil {
                self.stopEngineIfNeeded()
            }
        }
    }

    func stopRecognition() async throws -> String {
        recognitionRequest?.endAudio()
        stopEngineIfNeeded()
        return latestTranscript
    }

    private func stopEngineIfNeeded() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func meterLevels(from buffer: AVAudioPCMBuffer) -> [Double] {
        guard
            let channelData = buffer.floatChannelData?.pointee,
            buffer.frameLength > 0
        else {
            return [0.18, 0.22, 0.17, 0.24, 0.16, 0.2]
        }

        let sampleCount = Int(buffer.frameLength)
        let bucketSize = max(sampleCount / 6, 1)
        var levels: [Double] = []

        for bucket in 0..<6 {
            let start = bucket * bucketSize
            let end = min(start + bucketSize, sampleCount)
            guard start < end else {
                levels.append(0.18)
                continue
            }

            var peak: Float = 0
            for index in start..<end {
                peak = max(peak, abs(channelData[index]))
            }

            let normalized = min(max(Double(peak) * 1.8, 0.14), 0.92)
            levels.append(normalized)
        }

        return levels
    }
}

enum VoiceInputError: LocalizedError {
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "当前设备上的语音识别服务不可用。"
        }
    }
}
