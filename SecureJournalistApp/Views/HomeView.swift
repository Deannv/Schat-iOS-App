//
//  HomeView.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 17/02/26.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("isOnboarding") var isOnboarding: Bool?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatSession.timestamp, ascending: false)],
        animation: .default)
    private var chatSessions: FetchedResults<ChatSession>
    
    @State private var showContactSheet = false
    @State private var navigationPath = NavigationPath()
    
    @State private var searchText = ""
    @State private var selectedContactToNavigate: Contact? = nil
    
    var filteredSessions: [ChatSession] {
        if searchText.isEmpty {
            return Array(chatSessions)
        } else {
            return chatSessions.filter { session in
                (session.contactName ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            if filteredSessions.isEmpty {
                VStack {
                    VStack(alignment: .center){
                        Image(systemName: "questionmark.message")
                            .resizable()
                            .frame(width: 70, height: 60)
                            .foregroundStyle(Color(.systemGray3))
                        Text(searchText.isEmpty ?
                             "Start a conversation by tapping the icon on the top right of the screen."
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
                ForEach(filteredSessions) { session in
                    NavigationLink(value: session) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.black)
                            VStack(alignment: .leading) {
                                Text(session.contactName ?? "Unknown")
                                    .font(.headline)
                                Text(session.lastMessage ?? "Start conversation")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(session.timestamp ?? Date(), style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white.opacity(0.0))
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by name...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button{
                        withAnimation {
                            isOnboarding = true
                        }
                    }label:{
                        Image(systemName: "questionmark.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Schat")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showContactSheet = true }) {
                        Image(systemName: "square.and.pencil")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .navigationDestination(for: ChatSession.self) { session in
                ChatRoomView(session: session)
                    .toolbar(.hidden, for: .tabBar)
            }
            .sheet(isPresented: $showContactSheet, onDismiss: {
                if let contact = selectedContactToNavigate {
                    openChat(with: contact)
                    selectedContactToNavigate = nil
                }
            }) {
                ContactListView { selectedContact in
                    selectedContactToNavigate = selectedContact
                }
            }
        }
    }
    
    private func openChat(with contact: Contact) {
        let request: NSFetchRequest<ChatSession> = ChatSession.fetchRequest()
        request.predicate = NSPredicate(format: "contactID == %@", contact.userID ?? "")
        
        do {
            let results = try viewContext.fetch(request)
            if let existingSession = results.first {
                navigationPath.append(existingSession)
            } else {
                let newSession = ChatSession(context: viewContext)
                newSession.id = UUID()
                newSession.contactID = contact.userID
                newSession.contactName = contact.name
                newSession.timestamp = Date()
                newSession.lastMessage = "Secure conversation started"
                
                try viewContext.save()
                navigationPath.append(newSession)
            }
        } catch {
            print("Error checking session: \(error)")
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredSessions[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

#Preview {
    HomeView()
}
