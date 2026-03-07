//
//  NetworkManager.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 18/02/26.
//

import Foundation
import UIKit

class NetworkManager {
    static let shared = NetworkManager()
    
    private let serverBaseURL = "http://192.168.1.3:8000/api"
    
    // MARK: - 1. Upload Pesan (Sender)
    
    func uploadMessage(image: UIImage, sender: String, receiver: String, completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "\(serverBaseURL)/send-message"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "URL tidak valid", code: 400)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        guard let imageData = image.pngData() else {
            completion(.failure(NSError(domain: "Gagal konversi PNG", code: 400)))
            return
        }
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sender\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(sender)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"receiver\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(receiver)\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"stego_msg.png\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🚨 Network Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "Data Kosong", code: 204)))
                return
            }
            
            // DEBUGGING: Print apa yang sebenarnya dibalas oleh server
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("➡️ RAW UPLOAD RESPONSE: \n\(rawResponse)")
            }
            
            // CEK JSON: Pastikan server membalas format JSON yang valid
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    // Cek apakah balasan validasi error (422) atau sukses (201)
                    if let status = json["status"] as? String, status == "success" {
                        completion(.success("Upload Berhasil"))
                    } else if let message = json["message"] as? String {
                        // Jika Laravel membalas dengan pesan error validasi
                        completion(.failure(NSError(domain: "Server: \(message)", code: 422)))
                    } else {
                        completion(.failure(NSError(domain: "Gagal diverifikasi server", code: 500)))
                    }
                }
            } catch {
                completion(.failure(NSError(domain: "Respons server bukan JSON", code: 500)))
            }
        }.resume()
    }
    
    // MARK: - 2. Cek Pesan Masuk (Receiver)
    
    struct ServerMessageResponse: Codable {
        let status: String
        let data: [ServerMessage]
    }
    struct ServerMessage: Codable {
        let id: Int
        let sender_id: String
        let image_url: String
        let created_at: String
    }
    
    func fetchMessages(for receiverID: String, completion: @escaping (Result<[ServerMessage], Error>) -> Void) {
        let urlString = "\(serverBaseURL)/get-messages/\(receiverID)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "URL tidak valid", code: 400)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // PENTING: Memaksa respons JSON
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "Data Kosong", code: 204)))
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(ServerMessageResponse.self, from: data)
                completion(.success(decodedResponse.data))
            } catch {
                if let rawString = String(data: data, encoding: .utf8) {
                    print("🚨 ERROR PARSING JSON (Polling): \n\(rawString.prefix(200))...")
                }
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - 3. Download Gambar Fisik
    
    func downloadImage(from urlString: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        // Otomatis menyesuaikan IP localhost/127.0.0.1 dari Laravel ke IP aktual agar bisa diakses HP
        let fixedUrlString = urlString.replacingOccurrences(of: "localhost", with: "192.168.1.6")
                                      .replacingOccurrences(of: "127.0.0.1", with: "192.168.1.6")
        
        guard let url = URL(string: fixedUrlString) else {
            completion(.failure(NSError(domain: "Invalid Image URL", code: 400)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let data = data, let image = UIImage(data: data) {
                completion(.success(image))
            } else {
                completion(.failure(NSError(domain: "Bukan file gambar", code: 422)))
            }
        }.resume()
    }
}
