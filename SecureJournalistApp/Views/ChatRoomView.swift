//
//  ChatRoomView.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 18/02/26.
//

import SwiftUI
import PhotosUI
import CoreData

struct ChatRoomView: View {
    @StateObject var viewModel: ChatViewModel
    @State private var imageSelection: PhotosPickerItem? = nil
    @State private var isAnimatingMic = false
    @State private var showCamera = false
    
    // Source - https://stackoverflow.com/a/57594164
    // Posted by Ashish, modified by community. See post 'Timeline' for change history
    // Retrieved 2026-02-23, License - CC BY-SA 4.0
    @Environment(\.dismiss) private var dismiss

    
    init(session: ChatSession) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(session: session))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                
                // MARK: - Area List Pesan
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message, viewModel: viewModel)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGray6))
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.messages.count) { oldValue, newValue in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.selectedCoverImage) { oldValue, newValue in
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                // MARK: - Area Indikator Performa
                if viewModel.showPerformanceResult {
                    HStack {
                        Image(systemName: "timer")
                        Text("Comp. time: \(viewModel.processingTime)")
                            .font(.caption)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: { viewModel.showPerformanceResult = false }) {
                            Image(systemName: "xmark").font(.caption)
                        }
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: viewModel.showPerformanceResult)
                }
                
                Divider()
                
                // MARK: - Area Input Bawah
                VStack(spacing: 10) {
                    
                    if let img = viewModel.selectedCoverImage {
                        VStack(spacing: 8) {
                            HStack(alignment: .center, spacing: 12) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 45, height: 45)
                                    .cornerRadius(8)
                                    .overlay(
                                        Button(action: {
                                            viewModel.selectedCoverImage = nil
                                            if viewModel.isRecording { viewModel.toggleRecording() }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Circle().fill(Color.white))
                                        }.offset(x: 8, y: -8), alignment: .topTrailing
                                    )
                                
                                Text(viewModel.currentPayloadInfo)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                
                                Spacer()
                            }
                            
                            Divider()
                            
                            if viewModel.isRecording || viewModel.currentRecordingTime > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: viewModel.currentRecordingTime, total: viewModel.maxAudioDuration)
                                        .progressViewStyle(LinearProgressViewStyle(tint: viewModel.currentRecordingTime >= viewModel.maxAudioDuration * 0.9 ? .red : .blue))
                                    
                                    HStack {
                                        Text("\(String(format: "%.1f", viewModel.currentRecordingTime))s")
                                        Spacer()
                                        Text("\(String(format: "%.1f", viewModel.maxAudioDuration))s (Max)")
                                    }
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    HStack(spacing: 24) {
                        HStack(spacing: 16) {
                            Button(action: {
                                showCamera = true
                            }) {
                                Image(systemName: "camera")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black)
                            }
                            .disabled(viewModel.isRecording || viewModel.isProcessing)
                            
                            PhotosPicker(selection: $imageSelection, matching: .images) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black)
                            }
                            .disabled(viewModel.isRecording || viewModel.isProcessing)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            if viewModel.isRecording {
                                Circle()
                                    .stroke(Color.red.opacity(0.6), lineWidth: 4)
                                    .frame(width: 60, height: 60)
                                    .scaleEffect(isAnimatingMic ? 1.5 : 1.0)
                                    .opacity(isAnimatingMic ? 0.0 : 1.0)
                                    .animation(Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isAnimatingMic)
                                    .onAppear { isAnimatingMic = true }
                                    .onDisappear { isAnimatingMic = false }
                            }
                            
                            Button(action: {
                                viewModel.toggleRecording()
                            }) {
                                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(viewModel.isRecording ? Color.red : Color.black)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            .disabled(viewModel.isProcessing)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.sendMessage()
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "paperplane")
                                    .font(.system(size: 18))
                                Text("Send")
                                    .font(.caption)
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                (viewModel.selectedCoverImage != nil && !viewModel.isRecording && viewModel.currentRecordingTime > 0) ? .blue : .gray
                            )
                            .clipShape(Capsule())
                        }
                        .disabled(viewModel.selectedCoverImage == nil || viewModel.isRecording || viewModel.isProcessing || viewModel.currentRecordingTime == 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .background(Color(.white))
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack {
                        Image(systemName: "person.fill")
                            .font(.headline)
                        Text(viewModel.session.contactName ?? "Unknown")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            
            // MARK: - Overlay Loading
            if viewModel.isProcessing {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Processing...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(30)
                .background(Color(.systemGray6).opacity(0.2))
                .cornerRadius(16)
                .background(BlurView(style: .systemThinMaterialDark).cornerRadius(16))
            }
        }
        .onChange(of: imageSelection) { newItem in
            if let newItem {
                newItem.loadTransferable(type: Data.self) { result in
                    if case .success(let data?) = result, let uiImage = UIImage(data: data) {
                        DispatchQueue.main.async {
                            viewModel.selectedCoverImage = uiImage
                            viewModel.calculatePayloadCapacity()
                        }
                    }
                }
            }
        }
        .alert(item: Binding<AlertItem?>(
            get: { viewModel.errorMessage.map { AlertItem(message: $0) } },
            set: { _ in viewModel.errorMessage = nil }
        )) { alert in
            Alert(title: Text("Alert"), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(selectedImage: $viewModel.selectedCoverImage)
                .ignoresSafeArea()
        }
        .onChange(of: viewModel.selectedCoverImage) { newImage in
            if newImage != nil {
                DispatchQueue.main.async {
                    viewModel.calculatePayloadCapacity()
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = viewModel.messages.last?.id {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

// MARK: - Komponen UI Bubble Pesan

struct MessageBubble: View {
    let message: Message
    @ObservedObject var viewModel: ChatViewModel
    
    // Membaca status dari Core Data (aman dengan fallback 'sent' untuk pesan lama)
    var messageStatus: String {
        return (message.value(forKey: "status") as? String) ?? "sent"
    }
    
    var body: some View {
        HStack {
            if message.isFromMe { Spacer() }
            
            VStack(alignment: .trailing, spacing: 4) {
                if let path = message.imagePath,
                   let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    
                    let fileURL = docURL.appendingPathComponent(path)
                    if let uiImage = UIImage(contentsOfFile: fileURL.path) {
                        Button(action: {
                            viewModel.decryptAndPlay(message: message)
                        }) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 220)
                                .cornerRadius(12)
                                .overlay(
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                        .padding(6),
                                    alignment: .bottomTrailing
                                )
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    HStack(spacing: 4){
                        Text(message.timestamp ?? Date(), format: .dateTime.day().month().year())
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(message.timestamp ?? Date(), style: .time)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    if message.isFromMe {
                        if messageStatus == "pending" {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        } else if messageStatus == "sent" {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        } else if messageStatus == "failed" {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.trailing, 4)
            }
            .padding(6)
            .background(message.isFromMe ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
            .cornerRadius(16)
            
            if !message.isFromMe { Spacer() }
        }
    }
}

struct AlertItem: Identifiable {
    var id = UUID()
    var message: String
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
//    ChatRoomView()
}
