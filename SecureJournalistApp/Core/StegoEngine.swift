//
//  StegoEngine.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 17/02/26.
//

import Foundation
import UIKit
import CoreGraphics

/// Mesin utama Steganografi: Embed & Extract
class StegoEngine {
    
    static let shared = StegoEngine()
    private init() {}
    
    // MARK: - Embedding (Menyisipkan)
    
    /// Menyisipkan data Audio ke dalam Gambar (Randomized LSB)
    func embed(audioData: Data, into image: UIImage, password: String) -> UIImage? {
        
        // 0. Normalisasi Orientasi Gambar (MEMPERBAIKI BUG GAMBAR MIRING)
        // Memastikan piksel gambar digambar ulang agar tegak lurus sebelum dimanipulasi
        let normalizedImage = image.fixedOrientation()
        
        // 1. Inisialisasi PRNG dengan Seed Password
        let seed = CryptoManager.shared.deriveSeed(from: password)
        var prng = DeterministicPRNG(seed: seed)
        
        // 2. Siapkan Bitmap Context
        guard let cgImage = normalizedImage.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        
        // 3. Konversi Audio Data ke Bit Array
        // Format: [32-bit Panjang Data] + [Data Audio]
        let bitsToHide = convertDataToBits(audioData)
        
        // Cek Kapasitas (1 bit per piksel)
        if bitsToHide.count > totalPixels {
            print("Error: Kapasitas gambar tidak cukup. Butuh \(bitsToHide.count), ada \(totalPixels).")
            return nil
        }
        
        // 4. Siapkan Buffer Memori untuk Pixel Manipulation
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4 // RGBA
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
        
        // 5. Proses Penyisipan Bit Acak
        var usedCoordinates = Set<Int>() // Untuk Collision Handling
        
        for bit in bitsToHide {
            var pixelIndex = prng.next(upperBound: totalPixels)
            
            // Collision Handling: Jika piksel sudah dipakai, geser ke tetangga (Linear Probing)
            while usedCoordinates.contains(pixelIndex) {
                pixelIndex = (pixelIndex + 1) % totalPixels
            }
            usedCoordinates.insert(pixelIndex)
            
            // Manipulasi LSB pada Kanal BIRU (Blue Channel)
            // Struktur Pixel di memori: [Red, Green, Blue, Alpha]
            let byteIndex = pixelIndex * bytesPerPixel
            let blueIndex = byteIndex + 2
            
            var blueValue = rawData[blueIndex]
            
            // Logika LSB: (Nilai & 11111110) | Bit Pesan
            blueValue = (blueValue & 0xFE) | bit
            rawData[blueIndex] = blueValue
        }
        
        // 6. Buat Gambar Baru (Stego Image)
        guard let newCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage)
    }
    
    // MARK: - Extraction (Mengekstrak)
    
    /// Mengekstrak data Audio dari Gambar
    func extract(from image: UIImage, password: String) -> Data? {
        // Saat ekstraksi, kita tidak perlu menormalisasi gambar karena
        // gambar hasil embed sudah dinormalisasi dan tidak memiliki masalah metadata.
        
        // 1. Setup PRNG (Seed harus sama)
        let seed = CryptoManager.shared.deriveSeed(from: password)
        var prng = DeterministicPRNG(seed: seed)
        
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        let bytesPerPixel = 4
        
        // Akses Data Raw
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let rawData = CFDataGetBytePtr(data) else { return nil }
        
        var usedCoordinates = Set<Int>()
        
        // 2. Baca Header (32 bit pertama = Panjang Data)
        var lengthBits = [UInt8]()
        for _ in 0..<32 {
            var pixelIndex = prng.next(upperBound: totalPixels)
            while usedCoordinates.contains(pixelIndex) {
                pixelIndex = (pixelIndex + 1) % totalPixels
            }
            usedCoordinates.insert(pixelIndex)
            
            let blueIndex = (pixelIndex * bytesPerPixel) + 2
            let bit = rawData[blueIndex] & 1
            lengthBits.append(bit)
        }
        
        guard let dataLength = convertBitsToUInt32(lengthBits) else { return nil }
        
        // Sanity Check: Jika panjang data > total piksel, password pasti salah
        if dataLength > (totalPixels - 32) || dataLength == 0 {
            print("Gagal Ekstrak: Header length invalid (\(dataLength)). Password salah?")
            return nil
        }
        
        // 3. Baca Payload Audio
        var audioBits = [UInt8]()
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
        
        return convertBitsToData(audioBits)
    }
    
    // MARK: - Helper Methods
    
    private func convertDataToBits(_ data: Data) -> [UInt8] {
        var bits = [UInt8]()
        
        // Header Panjang (32 bit)
        let length = UInt32(data.count)
        withUnsafeBytes(of: length.bigEndian) { buffer in
             for byte in buffer {
                 for i in 0..<8 { bits.append((byte >> (7 - i)) & 1) }
             }
        }
        // Body Data
        for byte in data {
            for i in 0..<8 {
                bits.append((byte >> (7 - i)) & 1)
            }
        }
        return bits
    }
    
    private func convertBitsToUInt32(_ bits: [UInt8]) -> UInt32? {
        guard bits.count == 32 else { return nil }
        var value: UInt32 = 0
        for bit in bits {
            value = (value << 1) | UInt32(bit)
        }
        return value
    }
    
    private func convertBitsToData(_ bits: [UInt8]) -> Data {
        var bytes = [UInt8]()
        var currentByte: UInt8 = 0
        for (index, bit) in bits.enumerated() {
            currentByte = (currentByte << 1) | bit
            if (index + 1) % 8 == 0 {
                bytes.append(currentByte)
                currentByte = 0
            }
        }
        return Data(bytes)
    }
}

// MARK: - UIImage Extension untuk Normalisasi Orientasi
extension UIImage {
    /// Menggambar ulang gambar agar orientasinya terkunci ke atas (.up)
    /// dan menghapus ketergantungan pada metadata EXIF.
    func fixedOrientation() -> UIImage {
        // Jika sudah tegak, tidak perlu digambar ulang
        if self.imageOrientation == .up {
            return self
        }
        
        // Mulai menggambar ulang gambar ke dalam konteks grafis baru
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
