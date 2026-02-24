//
//  StegoEngine.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 17/02/26.
//

import Foundation
import UIKit
import CoreGraphics

class StegoEngine {
    
    static let shared = StegoEngine()
    
    // MARK: - Embedding Process (Menyisipkan)
    
    /// Menyisipkan data terenkripsi ke dalam gambar menggunakan Password
    func embed(audioData: Data, into image: UIImage, password: String) -> UIImage? {
        
        // 1. Siapkan Seed dari Password
        let seed = CryptoManager.shared.deriveSeed(from: password)
        var prng = DeterministicPRNG(seed: seed)
        
        // 2. Konversi Gambar ke Bitmap (CGImage)
        guard let cgImage = image.cgImage else {
            print("Gagal mendapatkan CGImage.")
            return nil
        }
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        
        // 3. Konversi Data Audio ke Array of Bits [0, 1, 1, 0...]
        // Header: 32 bit pertama adalah Panjang Data (UInt32)
        let bitsToHide = convertDataToBits(audioData)
        
        // Cek Kapasitas: 1 bit per piksel
        if bitsToHide.count > totalPixels {
            print("Error: Gambar terlalu kecil. Butuh \(bitsToHide.count) piksel, tersedia \(totalPixels).")
            return nil
        }
        
        // 4. Siapkan Context Bitmap untuk memodifikasi piksel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4 // Format RGBA
        let bytesPerRow = bytesPerPixel * width
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * bytesPerRow)
        defer { rawData.deallocate() }
        
        guard let context = CGContext(data: rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 5. Logika Penyisipan Acak (Randomized LSB)
        var usedCoordinates = Set<Int>() // Set untuk melacak piksel yang sudah dipakai (Collision Handling)
        
        for bit in bitsToHide {
            var pixelIndex = prng.next(upperBound: totalPixels)
            
            // Collision Handling: Jika piksel sudah dipakai, geser ke tetangga (Linear Probing)
            while usedCoordinates.contains(pixelIndex) {
                pixelIndex = (pixelIndex + 1) % totalPixels
            }
            usedCoordinates.insert(pixelIndex)
            
            // Akses data piksel di buffer
            // Struktur Byte: [R, G, B, A] -> Kita ubah kanal B (index + 2)
            let byteIndex = pixelIndex * bytesPerPixel
            let blueIndex = byteIndex + 2
            
            var blueValue = rawData[blueIndex]
            
            // Teknik LSB Replacement:
            // 1. Matikan bit terakhir (AND 11111110 / 0xFE)
            // 2. Masukkan bit pesan (OR bit)
            blueValue = (blueValue & 0xFE) | bit
            
            rawData[blueIndex] = blueValue
        }
        
        // 6. Buat Gambar Baru
        guard let newCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage)
    }
    
    // MARK: - Extraction Process (Mengekstrak)
    
    /// Mengekstrak data audio dari gambar steganografi
    func extract(from image: UIImage, password: String) -> Data? {
        
        // 1. Siapkan Seed & PRNG (Harus sama persis dengan proses Embed)
        let seed = CryptoManager.shared.deriveSeed(from: password)
        var prng = DeterministicPRNG(seed: seed)
        
        // 2. Akses Data Bitmap
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        // Ambil data raw dari gambar
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let rawData = CFDataGetBytePtr(data) else { return nil }
        
        var usedCoordinates = Set<Int>()
        
        // --- TAHAP A: Baca Header Panjang Data (32 Bit Pertama) ---
        var lengthBits = [UInt8]()
        for _ in 0..<32 {
            var pixelIndex = prng.next(upperBound: totalPixels)
            while usedCoordinates.contains(pixelIndex) {
                pixelIndex = (pixelIndex + 1) % totalPixels
            }
            usedCoordinates.insert(pixelIndex)
            
            let blueIndex = (pixelIndex * bytesPerPixel) + 2
            let bit = rawData[blueIndex] & 1 // Ambil LSB
            lengthBits.append(bit)
        }
        
        // Konversi 32 bits header menjadi Int (Panjang Data Audio)
        guard let dataLength = convertBitsToUInt32(lengthBits) else {
            print("Gagal membaca header panjang data.")
            return nil
        }
        
        // Validasi Panjang Data (Sanity Check)
        // Jika panjang data tidak masuk akal (misal > kapasitas gambar), berarti password salah atau gambar bukan stego.
        if dataLength > (totalPixels - 32) || dataLength == 0 {
            print("Header length invalid: \(dataLength). Password mungkin salah.")
            return nil
        }
        
        // --- TAHAP B: Baca Data Audio (Payload) ---
        var audioBits = [UInt8]()
        // Jumlah bit yang harus dibaca = Panjang Byte * 8
        let totalBitsToRead = Int(dataLength) * 8
        
        for _ in 0..<totalBitsToRead {
            var pixelIndex = prng.next(upperBound: totalPixels)
            while usedCoordinates.contains(pixelIndex) {
                pixelIndex = (pixelIndex + 1) % totalPixels
            }
            usedCoordinates.insert(pixelIndex)
            
            let blueIndex = (pixelIndex * bytesPerPixel) + 2
            let bit = rawData[blueIndex] & 1
            audioBits.append(bit)
        }
        
        // Konversi bits kembali menjadi Data
        return convertBitsToData(audioBits)
    }
    
    // MARK: - Helper Functions
    
    /// Mengubah Data menjadi array Bit [0, 1...] dengan Header 32-bit Length
    private func convertDataToBits(_ data: Data) -> [UInt8] {
        var bits = [UInt8]()
        
        // 1. Tambahkan Header Panjang (32 bit Big Endian)
        let length = UInt32(data.count)
        withUnsafeBytes(of: length.bigEndian) { buffer in
             for byte in buffer {
                 for i in 0..<8 { bits.append((byte >> (7 - i)) & 1) }
             }
        }
        
        // 2. Tambahkan Data Asli
        for byte in data {
            for i in 0..<8 {
                bits.append((byte >> (7 - i)) & 1)
            }
        }
        return bits
    }
    
    /// Mengubah 32 bit array menjadi UInt32
    private func convertBitsToUInt32(_ bits: [UInt8]) -> UInt32? {
        guard bits.count == 32 else { return nil }
        var value: UInt32 = 0
        for bit in bits {
            value = (value << 1) | UInt32(bit)
        }
        return value // Hasil ini sudah Big Endian value secara logika urutan bit
    }
    
    /// Mengubah array Bit menjadi Data
    private func convertBitsToData(_ bits: [UInt8]) -> Data {
        var bytes = [UInt8]()
        var currentByte: UInt8 = 0
        
        for (index, bit) in bits.enumerated() {
            // Geser bit masuk ke byte
            currentByte = (currentByte << 1) | bit
            
            // Setiap 8 bit, simpan sebagai 1 byte
            if (index + 1) % 8 == 0 {
                bytes.append(currentByte)
                currentByte = 0
            }
        }
        return Data(bytes)
    }
}
