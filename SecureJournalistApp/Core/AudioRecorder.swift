//
//  AudioRecorder.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 17/02/26.
//


import Foundation
import AVFoundation
internal import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    
    var audioRecorder: AVAudioRecorder?
    @Published var isRecording = false
    @Published var recordedFileURL: URL?
    
    /// Memulai perekaman
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM), // WAJIB WAV (PCM)
                AVSampleRateKey: 44100.0,                  // Kualitas CD
                AVNumberOfChannelsKey: 1,                  // Mono (Hemat Size)
                AVLinearPCMBitDepthKey: 16,                // 16-bit standard
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]
            
            let fileName = "secret_audio.wav"
            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
            print("Recording started at: \(url.path)")
            
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    /// Menghentikan perekaman
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordedFileURL = audioRecorder?.url
        print("Recording stopped.")
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
