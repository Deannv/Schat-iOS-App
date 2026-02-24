//
//  ProfileView.swift
//  SecureJournalistApp
//
//  Created by Kemas Deanova on 21/02/26.
//

import SwiftUI

struct ProfileView: View {
    @State private var isIDVisible = false
    @State private var myUserID: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 80))
                    .foregroundColor(.black)
                    .padding(.top, 40)
                
                Text("My Profile")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Profile ID")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        if isIDVisible {
                            Text(myUserID)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text("••••••••-••••-••••-••••-••••••••••••")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                isIDVisible.toggle()
                            }
                        }) {
                            Image(systemName: isIDVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.black)
                                .font(.title3)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Text("Use this ID to connect with people, hold to copy or use the share button below.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    ShareLink(
                        item: myUserID,
                        subject: Text("Schat App ID"),
                        message: Text("Add me to Schat with this ID.")
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
                            Text("Share My ID")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 10)
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .onAppear {
                loadUserID()
            }
        }
    }
    
    private func loadUserID() {
        if let id = UserDefaults.standard.string(forKey: "DeviceUserID") {
            myUserID = id
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "DeviceUserID")
            myUserID = newID
        }
    }
}

#Preview {
    ProfileView()
}
