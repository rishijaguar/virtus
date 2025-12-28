//
//  ProfileView.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    // Get the first profile or a placeholder if none exists
    private var userProfile: UserProfile {
        profiles.first ?? UserProfile()
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Basic Info")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(userProfile.name)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Coach's Knowledge")) {
                    ProfileRow(title: "Goals", text: userProfile.goals, icon: "target")
                    ProfileRow(title: "Injuries", text: userProfile.injuries, icon: "bandage")
                    ProfileRow(title: "Preferences", text: userProfile.preferences, icon: "heart")
                }
                
                Section(header: Text("Internal Coach Notes"), footer: Text("These are private notes the coach uses to tailor your experience.")) {
                    Text(userProfile.coachNotes.isEmpty ? "No internal notes yet." : userProfile.coachNotes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                ensureProfileExists()
            }
        }
    }
    
    private func ensureProfileExists() {
        if profiles.isEmpty {
            let newProfile = UserProfile(name: "Athlete")
            modelContext.insert(newProfile)
            try? modelContext.save()
        }
    }
}

struct ProfileRow: View {
    let title: String
    let text: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                Spacer()
            }
            
            if text.isEmpty {
                Text("Not set yet. Talk to the coach to update this.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(text)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
