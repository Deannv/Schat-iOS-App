//
//  ContactListView.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 18/02/26.
//

import SwiftUI
import CoreData

struct ContactListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Contact.name, ascending: true)],
        animation: .default)
    private var contacts: FetchedResults<Contact>
    
    // State untuk Tambah Kontak
    @State private var showAddContactAlert = false
    @State private var newName = ""
    @State private var newUserID = ""
    @State private var newPassword = ""
    
    // State untuk Edit Kontak
    @State private var showEditContactAlert = false
    @State private var contactToEdit: Contact? = nil
    @State private var editName = ""
    @State private var editPassword = ""
    @State private var readOnlyUserID = ""
    
    var onSelectContact: (Contact) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(contacts) { contact in
                    Button(action: {
                        onSelectContact(contact)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name ?? "Unknown")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let uid = contact.value(forKey: "userID") as? String, !uid.isEmpty {
                                    Text("ID: \(uid.prefix(8))...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .monospaced()
                                }
                            }
                        }
                    }
                    // Aksi Geser (Swipe Actions) untuk Edit dan Hapus
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteContact(contact)
                        } label: {
                            Label("Hapus", systemImage: "trash")
                        }
                        
                        Button {
                            prepareEdit(for: contact)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("Pilih Kontak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddContactAlert = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Tutup") { dismiss() }
                }
            }
            // Alert Tambah Kontak
            .alert("Tambah Kontak Baru", isPresented: $showAddContactAlert) {
                TextField("Nama / Alias (Bebas)", text: $newName)
                TextField("ID Perangkat Kontak (UUID)", text: $newUserID)
                SecureField("Password Bersama", text: $newPassword)
                
                Button("Batal", role: .cancel) { resetAddForm() }
                Button("Simpan") { addContact() }
            } message: {
                Text("Masukkan nama, ID asli dari lawan bicara, dan password rahasia yang telah disepakati.")
            }
            // Alert Edit Kontak
            .alert("Edit Kontak", isPresented: $showEditContactAlert) {
                TextField("Nama / Alias", text: $editName)
                SecureField("Password Baru (Kosongkan jika tetap)", text: $editPassword)
                
                Button("Batal", role: .cancel) { resetEditForm() }
                Button("Simpan") { saveEdit() }
            } message: {
                Text("ID: \(readOnlyUserID)\n(ID tidak dapat diubah)")
            }
        }
    }
    
    // MARK: - Core Logic Add & Delete
    
    private func addContact() {
        let cleanedUserID = newUserID
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ").first ?? newUserID
            
        guard !newName.isEmpty && !cleanedUserID.isEmpty && !newPassword.isEmpty else { return }
        
        withAnimation {
            let newItem = Contact(context: viewContext)
            newItem.id = UUID()
            newItem.name = newName
            newItem.setValue(cleanedUserID, forKey: "userID")
            newItem.createdAt = Date()
            
            KeychainHelper.shared.savePassword(newPassword, forContact: newName)
            try? viewContext.save()
            resetAddForm()
        }
    }
    
    private func deleteContact(_ contact: Contact) {
        withAnimation {
            if let name = contact.name {
                KeychainHelper.shared.deletePassword(forContact: name)
            }
            viewContext.delete(contact)
            try? viewContext.save()
        }
    }
    
    // MARK: - Core Logic Edit
    
    private func prepareEdit(for contact: Contact) {
        contactToEdit = contact
        editName = contact.name ?? ""
        readOnlyUserID = (contact.value(forKey: "userID") as? String) ?? "Tidak diketahui"
        editPassword = "" // Biarkan kosong agar user tidak perlu mengetik ulang jika tidak ingin diganti
        showEditContactAlert = true
    }
    
    private func saveEdit() {
        guard let contact = contactToEdit, !editName.isEmpty else { return }
        let oldName = contact.name ?? ""
        
        withAnimation {
            // 1. Tangani Perubahan Password & Nama di Keychain
            if oldName != editName {
                // Nama berubah, pindahkan password lama ke kunci nama baru (atau update jika diketik baru)
                let oldPassword = KeychainHelper.shared.getPassword(forContact: oldName) ?? ""
                let passToSave = editPassword.isEmpty ? oldPassword : editPassword
                
                KeychainHelper.shared.deletePassword(forContact: oldName)
                KeychainHelper.shared.savePassword(passToSave, forContact: editName)
                
                // 2. Sinkronisasi Nama di ChatSession (Agar riwayat chat tidak hilang)
                let request: NSFetchRequest<ChatSession> = ChatSession.fetchRequest()
                request.predicate = NSPredicate(format: "contactName == %@", oldName)
                if let sessions = try? viewContext.fetch(request) {
                    for session in sessions {
                        session.contactName = editName
                    }
                }
                
            } else if !editPassword.isEmpty {
                // Nama sama, tapi password diupdate
                KeychainHelper.shared.savePassword(editPassword, forContact: oldName)
            }
            
            // 3. Simpan Perubahan Nama ke CoreData
            contact.name = editName
            try? viewContext.save()
            resetEditForm()
        }
    }
    
    // MARK: - Helpers
    private func resetAddForm() { newName = ""; newUserID = ""; newPassword = "" }
    private func resetEditForm() { contactToEdit = nil; editName = ""; editPassword = ""; readOnlyUserID = "" }
}
