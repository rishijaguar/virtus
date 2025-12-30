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
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    
    var body: some View {
        NavigationStack {
            if let profile = profiles.first {
                ProfileContent(userProfile: profile, exercises: exercises)
            } else {
                ContentUnavailableView("Loading Profile...", systemImage: "person.circle")
                    .onAppear { ensureProfileExists() }
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

struct ProfileContent: View {
    @Bindable var userProfile: UserProfile
    let exercises: [Exercise]
    @State private var showing1RMEditor = false
    
    var body: some View {
        List {
            Section("Basic Info") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(userProfile.name)
                        .foregroundColor(.secondary)
                }
                
                Picker("Preferred Unit", selection: $userProfile.preferredUnitRaw) {
                    Text("Pounds (lbs)").tag("lbs")
                    Text("Kilograms (kg)").tag("kg")
                }
            }
            
            Section("Training Maxes (1RM)") {
                Button("Manage 1RMs") {
                    showing1RMEditor = true
                }
                
                // Show top 3 maxes as summary
                let setMaxes = exercises.compactMap { ex -> (String, Double)? in
                    guard let max = userProfile.oneRepMax(for: ex.id) else { return nil }
                    return (ex.name, max)
                }.sorted { $0.1 > $1.1 }
                
                ForEach(setMaxes.prefix(5), id: \.0) { item in
                    HStack {
                        Text(item.0)
                        Spacer()
                        Text("\(Int(item.1)) \(userProfile.preferredUnitRaw)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Coach's Knowledge") {
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
        .sheet(isPresented: $showing1RMEditor) {
            OneRepMaxEditorView(profile: userProfile, exercises: exercises)
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

struct OneRepMaxEditorView: View {
    let profile: UserProfile
    let exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    
    @State private var maxes: [UUID: Double] = [:]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(exercises) { exercise in
                    HStack {
                        Text(exercise.name)
                            .font(.subheadline)
                        Spacer()
                        
                        TextField("100", value: binding(for: exercise.id), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Text(profile.preferredUnitRaw)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit 1RMs")
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onAppear {
                // Load existing maxes into local state
                for ex in exercises {
                    if let val = profile.oneRepMax(for: ex.id) {
                        maxes[ex.id] = val
                    }
                }
            }
        }
    }
    
    private func binding(for id: UUID) -> Binding<Double> {
        Binding(
            get: { maxes[id] ?? 0.0 },
            set: { newValue in
                maxes[id] = newValue
                profile.setOneRepMax(newValue, for: id)
            }
        )
    }
}