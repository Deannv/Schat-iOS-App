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
    
    @State private var searchContact = ""
    
    var filteredContacts: [Contact] {
        if searchContact.isEmpty {
            return Array(contacts)
        } else {
            return contacts.filter { contact in
                (contact.name ?? "").localizedCaseInsensitiveContains(searchContact)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            
            if filteredContacts.isEmpty {
                VStack {
                    VStack(alignment: .center){
                        Image(systemName: "person.text.rectangle")
                            .resizable()
                            .frame(width: 70, height: 60)
                            .foregroundStyle(Color(.systemGray3))
                        Text(searchContact.isEmpty ?
                             "Add new contact to start a conversation."
                             : "No results were found.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(.systemGray3))
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20).stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [10, 5]))
                    )
                }
                .padding()
            }
            
            List {
                ForEach(filteredContacts) { contact in
                    Button(action: {
                        onSelectContact(contact)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundColor(.black)
                            
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteContact(contact)
                        } label: {
                            Label("Delete", systemImage: "trash")
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
            .searchable(text: $searchContact, prompt: "Search by name...")
            .navigationTitle("New chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddContactAlert = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Add new contact", isPresented: $showAddContactAlert) {
                TextField("Name / Initial", text: $newName)
                TextField("User ID", text: $newUserID)
                SecureField("Shared Password", text: $newPassword)
                
                Button("Cancel", role: .cancel) { resetAddForm() }
                Button("Save") { addContact() }
            } message: {
                Text("Insert name, ID and shared password that you have agreed.")
            }
            .alert("Edit contact", isPresented: $showEditContactAlert) {
                TextField("Nama / Initial", text: $editName)
                SecureField("New password (leave it empty to keep the old one)", text: $editPassword)
                
                Button("Cancel", role: .cancel) { resetEditForm() }
                Button("Update") { saveEdit() }
            } message: {
                Text("ID: \(readOnlyUserID)\n(ID cannot be changed)")
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
        readOnlyUserID = (contact.value(forKey: "userID") as? String) ?? "Unknown"
        editPassword = ""
        showEditContactAlert = true
    }
    
    private func saveEdit() {
        guard let contact = contactToEdit, !editName.isEmpty else { return }
        let oldName = contact.name ?? ""
        
        withAnimation {
            if oldName != editName {
                let oldPassword = KeychainHelper.shared.getPassword(forContact: oldName) ?? ""
                let passToSave = editPassword.isEmpty ? oldPassword : editPassword
                
                KeychainHelper.shared.deletePassword(forContact: oldName)
                KeychainHelper.shared.savePassword(passToSave, forContact: editName)
                
                let request: NSFetchRequest<ChatSession> = ChatSession.fetchRequest()
                request.predicate = NSPredicate(format: "contactName == %@", oldName)
                if let sessions = try? viewContext.fetch(request) {
                    for session in sessions {
                        session.contactName = editName
                    }
                }
                
            } else if !editPassword.isEmpty {
                KeychainHelper.shared.savePassword(editPassword, forContact: oldName)
            }
            
            contact.name = editName
            try? viewContext.save()
            resetEditForm()
        }
    }
    
    // MARK: - Helpers
    private func resetAddForm() { newName = ""; newUserID = ""; newPassword = "" }
    private func resetEditForm() { contactToEdit = nil; editName = ""; editPassword = ""; readOnlyUserID = "" }
}
