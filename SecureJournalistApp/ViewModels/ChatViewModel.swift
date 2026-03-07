//
//  ChatViewModel.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 18/02/26.
//

import SwiftUI
import CoreData
import AVFoundation
import PhotosUI
internal import Combine

@MainActor
class ChatViewModel: ObservableObject {
    
    // Dependencies
    private let viewContext = PersistenceController.shared.container.viewContext
    private let cryptoManager = CryptoManager.shared
    private let stegoEngine = StegoEngine.shared
    private let audioRecorder = AudioRecorder()
    
    // Data Model
    let session: ChatSession
    @Published var messages: [Message] = []
    
    // UI State
    @Published var selectedCoverImage: UIImage? = nil
    @Published var isRecording = false
    @Published var errorMessage: String? = nil
    @Published var isProcessing = false
    
    // UX: Payload
    @Published var maxAudioDuration: Double = 0.0
    @Published var currentPayloadInfo: String = "Choose an image to calculate the payload."
    @Published var currentRecordingTime: Double = 0.0
    private var recordingTimer: Timer?
    
    // UX: Performance Indicator
    @Published var processingTime: String = ""
    @Published var showPerformanceResult = false
    
    // Audio Player
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlayingAudio = false
    
    private var sessionPassword: String = ""
    private var contactUserID: String = ""
    
    private var pollingTimer: Timer?
    
    var myUserID: String {
        if let id = UserDefaults.standard.string(forKey: "DeviceUserID") { return id }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: "DeviceUserID")
        return newID
    }
    
    init(session: ChatSession) {
        self.session = session
        fetchMessages()
        fetchContactDetails()
        startPolling()
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
    
    // MARK: - 1. Setup
    
    private func fetchContactDetails() {
        guard let contactName = session.contactName else { return }
        
        if let pwd = KeychainHelper.shared.getPassword(forContact: contactName) {
            self.sessionPassword = pwd
        } else {
            errorMessage = "Shared password not found or empty."
        }
        
        let request: NSFetchRequest<Contact> = Contact.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", contactName)
        do {
            if let contact = try viewContext.fetch(request).first,
               let uid = contact.value(forKey: "userID") as? String {
                self.contactUserID = uid
            } else {
                errorMessage = "Contact ID not found, cannot send the message."
            }
        } catch {
            print("Error fetch contact: \(error)")
        }
    }
    
    func fetchMessages() {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "chatSession == %@", session)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.timestamp, ascending: true)]
        do { messages = try viewContext.fetch(request) } catch { print(error) }
    }
    
    // MARK: - 2. POLLING (Menarik Pesan Baru)
    
    func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkForNewMessages()
        }
    }
    
    @objc private func checkForNewMessages() {
        NetworkManager.shared.fetchMessages(for: myUserID) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let serverMessages):
                let relevantMessages = serverMessages.filter { $0.sender_id == self.contactUserID }
                
                for msg in relevantMessages {
                    self.processIncomingMessage(msg)
                }
            case .failure(let error):
                print("Polling error: \(error.localizedDescription)")
            }
        }
    }
    
    private func processIncomingMessage(_ serverMsg: NetworkManager.ServerMessage) {
        NetworkManager.shared.downloadImage(from: serverMsg.image_url) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let downloadedImage):
                    if let savedPath = self.saveImageToDocuments(image: downloadedImage) {
                        
                        _ = self.saveMessageToCoreData(imagePath: savedPath, isFromMe: false, status: "received")
                        
                        AudioServicesPlaySystemSound(1003)
                    }
                case .failure(let error):
                    print("Failed to download the image: \(error)")
                }
            }
        }
    }
    
    // MARK: - 3. Payload & Recording
    
    func calculatePayloadCapacity() {
        guard let image = selectedCoverImage, let cgImage = image.cgImage else {
            maxAudioDuration = 0
            currentPayloadInfo = "Choose an image."
            return
        }
        let totalPixels = Double(cgImage.width * cgImage.height)
        self.maxAudioDuration = ((totalPixels - 32.0) / 705600.0) * 0.90
        self.currentPayloadInfo = "Capacity: \(cgImage.width)x\(cgImage.height) px | Limit: \(String(format: "%.1f", self.maxAudioDuration))s"
    }
    
    func toggleRecording() {
        if audioRecorder.isRecording { stopRecordingProcess() }
        else {
            if selectedCoverImage == nil { errorMessage = "Please choose the image cover before recording audio message."; return }
            if sessionPassword.isEmpty { errorMessage = "Password has been unset or empty."; return }
            startRecordingProcess()
        }
    }
    
    private func startRecordingProcess() {
        audioRecorder.startRecording()
        isRecording = true
        currentRecordingTime = 0.0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentRecordingTime += 0.1
                if self.currentRecordingTime >= self.maxAudioDuration {
                    self.stopRecordingProcess()
                    self.errorMessage = "Reached the limit for audio duration. The recording has been stopped automatically."
                }
            }
        }
    }
    private func stopRecordingProcess() {
        audioRecorder.stopRecording()
        isRecording = false
        recordingTimer?.invalidate()
    }
    
    // MARK: - 4. Pengiriman (Upload)
    
    func sendMessage() {
        if currentRecordingTime == 0{
            errorMessage = "Please record a voice note before sending the message.";
            return
        }
        
        guard let coverImage = selectedCoverImage, let audioURL = audioRecorder.recordedFileURL else { return }
        guard !contactUserID.isEmpty else { errorMessage = "Contact ID is invalid or incorrect."; return }
        
        isProcessing = true
        showPerformanceResult = false
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let startTime = CFAbsoluteTimeGetCurrent()
                let audioData = try Data(contentsOf: audioURL)
                let key = self.cryptoManager.deriveKey(from: self.sessionPassword)
                let encryptedData = try self.cryptoManager.encryptAudio(data: audioData, key: key)
                
                if let stegoImage = self.stegoEngine.embed(audioData: encryptedData, into: coverImage, password: self.sessionPassword) {
                    
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let timeElapsed = (endTime - startTime) * 1000
                    
                    if let savedPath = self.saveImageToDocuments(image: stegoImage) {
                        DispatchQueue.main.async {
                            self.processingTime = String(format: "%.2f ms", timeElapsed)
                            self.showPerformanceResult = true
                            
                            let savedMessage = self.saveMessageToCoreData(imagePath: savedPath, isFromMe: true, status: "pending")
                            self.resetInput()
                            self.isProcessing = false
                            
                            NetworkManager.shared.uploadMessage(
                                image: stegoImage,
                                sender: self.myUserID,
                                receiver: self.contactUserID
                            ) { result in
                                DispatchQueue.main.async {
                                    switch result {
                                    case .success: savedMessage.setValue("sent", forKey: "status")
                                    case .failure: savedMessage.setValue("failed", forKey: "status")
                                    }
                                    try? self.viewContext.save()
                                    self.fetchMessages()
                                }
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async { self.errorMessage = "Failed: The audio file is too big."; self.isProcessing = false }
                }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "Error Cryptography: \(error.localizedDescription)"; self.isProcessing = false }
            }
        }
    }
    
    // MARK: - 5. Receiving (Extract & Decrypt)
    
    func decryptAndPlay(message: Message) {
        guard let imagePath = message.imagePath,
              let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fullPath = docDir.appendingPathComponent(imagePath).path
        guard let image = UIImage(contentsOfFile: fullPath) else { return }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            if let encryptedData = self.stegoEngine.extract(from: image, password: self.sessionPassword) {
                do {
                    let key = self.cryptoManager.deriveKey(from: self.sessionPassword)
                    let audioData = try self.cryptoManager.decryptAudio(combinedData: encryptedData, key: key)
                    
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let timeElapsed = (endTime - startTime) * 1000
                    
                    DispatchQueue.main.async {
                        self.processingTime = String(format: "%.2f ms (Extraction)", timeElapsed)
                        self.showPerformanceResult = true
                        
                        self.playAudio(data: audioData)
                        self.isProcessing = false
                    }
                } catch {
                    DispatchQueue.main.async { self.errorMessage = "Decryption Failed."; self.isProcessing = false }
                }
            } else {
                DispatchQueue.main.async { self.errorMessage = "Failed to extract the message, try checking the password."; self.isProcessing = false }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func saveImageToDocuments(image: UIImage) -> String? {
        guard let data = image.pngData(),
              let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileName = UUID().uuidString + ".png"
        let fileURL = docDir.appendingPathComponent(fileName)
        do { try data.write(to: fileURL); return fileName } catch { return nil }
    }
    
    private func saveMessageToCoreData(imagePath: String, isFromMe: Bool, status: String) -> Message {
        let newMessage = Message(context: viewContext)
        newMessage.id = UUID()
        newMessage.timestamp = Date()
        newMessage.isFromMe = isFromMe
        newMessage.imagePath = imagePath
        newMessage.chatSession = session
        newMessage.setValue(status, forKey: "status")
        
        session.lastMessage = isFromMe ? "📷 You sent a photo" : "📷 Sent a photo"
        session.timestamp = Date()
        
        try? viewContext.save()
        fetchMessages()
        return newMessage
    }
    
    private func resetInput() {
        selectedCoverImage = nil
        currentRecordingTime = 0.0
    }
    
    private func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
            isPlayingAudio = true
        } catch { print("Audio play error") }
    }
}
