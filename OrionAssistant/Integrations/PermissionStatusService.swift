import AVFAudio
import AVFoundation
import CoreLocation
import EventKit
import Foundation
import Speech
import UserNotifications

struct PermissionStatusSnapshot {
    let calendarAccessGranted: Bool
    let remindersAccessGranted: Bool
    let notificationsAccessGranted: Bool
    let locationAccessGranted: Bool
    let cameraAccessGranted: Bool
    let microphoneAccessGranted: Bool
    let speechRecognitionGranted: Bool
}

extension PermissionStatusSnapshot {
    func integrationStatus(llmProviderName: String) -> IntegrationStatus {
        IntegrationStatus(
            calendarAccessGranted: calendarAccessGranted,
            remindersAccessGranted: remindersAccessGranted,
            notificationsAccessGranted: notificationsAccessGranted,
            locationAccessGranted: locationAccessGranted,
            cameraAccessGranted: cameraAccessGranted,
            microphoneAccessGranted: microphoneAccessGranted,
            speechRecognitionGranted: speechRecognitionGranted,
            llmProviderName: llmProviderName
        )
    }

    var voicePermissionSummary: VoicePermissionSummary {
        VoicePermissionSummary(
            microphoneGranted: microphoneAccessGranted,
            speechRecognitionGranted: speechRecognitionGranted
        )
    }
}

@MainActor
final class PermissionStatusService {
    func refresh() async -> PermissionStatusSnapshot {
        let calendarAccessGranted = Self.isGranted(EKEventStore.authorizationStatus(for: .event))
        let remindersAccessGranted = Self.isGranted(EKEventStore.authorizationStatus(for: .reminder))
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        let notificationsAccessGranted = Self.isGranted(notificationSettings.authorizationStatus)
        let locationAccessGranted = Self.isGranted(CLLocationManager().authorizationStatus)
        let cameraAccessGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        let microphoneAccessGranted = AVAudioApplication.shared.recordPermission == .granted
        let speechRecognitionGranted = SFSpeechRecognizer.authorizationStatus() == .authorized

        return PermissionStatusSnapshot(
            calendarAccessGranted: calendarAccessGranted,
            remindersAccessGranted: remindersAccessGranted,
            notificationsAccessGranted: notificationsAccessGranted,
            locationAccessGranted: locationAccessGranted,
            cameraAccessGranted: cameraAccessGranted,
            microphoneAccessGranted: microphoneAccessGranted,
            speechRecognitionGranted: speechRecognitionGranted
        )
    }

    private static func isGranted(_ status: EKAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .fullAccess, .writeOnly:
            true
        case .denied, .restricted, .notDetermined:
            false
        @unknown default:
            false
        }
    }

    private static func isGranted(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        case .denied, .notDetermined:
            false
        @unknown default:
            false
        }
    }

    private static func isGranted(_ status: CLAuthorizationStatus) -> Bool {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            true
        case .denied, .restricted, .notDetermined:
            false
        @unknown default:
            false
        }
    }
}
