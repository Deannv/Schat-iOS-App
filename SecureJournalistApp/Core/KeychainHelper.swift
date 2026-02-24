//
//  KeychainHelper.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 19/02/26.
//

import Foundation
import Security

/// Kelas pembantu untuk mengelola penyimpanan password yang aman menggunakan iOS Keychain
class KeychainHelper {
    static let shared = KeychainHelper()
    
    /// Menyimpan data biner ke Keychain
    private func save(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary
        
        // Hapus data lama jika sudah ada untuk mencegah duplikasi
        SecItemDelete(query)
        
        // Tambahkan data baru
        SecItemAdd(query, nil)
    }
    
    /// Membaca data biner dari Keychain
    private func read(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        return result as? Data
    }
    
    /// Menghapus item dari Keychain
    func delete(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary
        
        SecItemDelete(query)
    }
    
    // MARK: - Helper untuk String Password
    
    /// Menyimpan password string untuk sebuah nama kontak
    func savePassword(_ pass: String, forContact contactName: String) {
        if let data = pass.data(using: .utf8) {
            save(data, service: "com.securejournalist.app", account: contactName)
        }
    }
    
    /// Mengambil password string berdasarkan nama kontak
    func getPassword(forContact contactName: String) -> String? {
        if let data = read(service: "com.securejournalist.app", account: contactName) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    /// Menghapus password kontak
    func deletePassword(forContact contactName: String) {
        delete(service: "com.securejournalist.app", account: contactName)
    }
}
