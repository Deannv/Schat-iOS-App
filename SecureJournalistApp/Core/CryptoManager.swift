//
//  CryptoManager.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 17/02/26.
//


import Foundation
import CryptoKit

/// Menangani semua operasi Kriptografi (Hashing & Enkripsi AES)
class CryptoManager {
    
    // Singleton instance
    static let shared = CryptoManager()
    private init() {}
    
    // MARK: - Hashing (SHA256)
    
    /// Mengubah Password String menjadi Kunci Simetris 256-bit
    func deriveKey(from password: String) -> SymmetricKey {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return SymmetricKey(data: digest)
    }
    
    /// Mengubah Password menjadi UInt64 untuk Seed PRNG
    func deriveSeed(from password: String) -> UInt64 {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        // Mengambil 8 byte pertama dari hash untuk dijadikan integer
        let subdata = Data(digest).prefix(8)
        return subdata.withUnsafeBytes { $0.load(as: UInt64.self) }
    }
    
    // MARK: - AES Encryption (GCM Mode)
    
    /// Mengenkripsi data Audio .wav
    func encryptAudio(data: Data, key: SymmetricKey) throws -> Data {
        // AES.GCM.seal membungkus data terenkripsi + Tag otentikasi + Nonce
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        // Kita gabungkan (combined) agar mudah disisipkan sebagai satu blob data
        guard let combinedData = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combinedData
    }
    
    /// Mendekripsi data Audio
    func decryptAudio(combinedData: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return decryptedData
    }
}

enum CryptoError: Error {
    case encryptionFailed
    case decryptionFailed
}