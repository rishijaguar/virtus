//
//  ProgramViews.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import SwiftUI
import SwiftData

struct ProgramListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Program.createdDate, order: .reverse) private var programs: [Program]
    @State private var showingCreateSheet = false
    
    var body: some View {
        List {
            if programs.isEmpty {
                ContentUnavailableView("No Programs", systemImage: "doc.text", description: Text("Create a program manually or ask the Coach to build one."))
            } else {
                ForEach(programs) { program in
                    NavigationLink(destination: ProgramDetailView(program: program)) {
                        VStack(alignment: .leading) {
                            Text(program.name)
                                .font(.headline)
                            Text("\(program.durationWeeks) Weeks • \(program.programDescription)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteProgram)
            }
        }
        .navigationTitle("Programs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCreateSheet = true }) {
                    Label("New Program", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateProgramView()
        }
    }
    
    private func deleteProgram(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(programs[index])
        }
    }
}

struct ProgramDetailView: View {
    @Bindable var program: Program
    @State private var isEditing = false
    
    var body: some View {
        List {
            Section(header: Text("Overview")) {
                Text(program.programDescription)
                LabeledContent("Duration", value: "\(program.durationWeeks) Weeks")
                LabeledContent("Frequency", value: "\(program.sessionsPerWeek) Sessions/Week")
            }
            
            ForEach(1...program.durationWeeks, id: \.self) { week in
                ProgramWeekSection(week: week, sessions: program.sessions)
            }
        }
        .navigationTitle(program.name)
        .toolbar {
            Button("Edit") {
                isEditing = true
            }
        }
        .sheet(isPresented: $isEditing) {
            ProgramEditSheet(program: program)
        }
    }
}

struct ProgramWeekSection: View {
    let week: Int
    let sessions: [SessionTemplate]
    
    var sessionsInWeek: [SessionTemplate] {
        sessions.filter { $0.weekNumber == week }.sorted { $0.dayNumber < $1.dayNumber }
    }
    
    var body: some View {
        Section(header: Text("Week \(week)")) {
            if sessionsInWeek.isEmpty {
                Text("No sessions scheduled.")
                    .italic()
                    .foregroundColor(.secondary)
            } else {
                ForEach(sessionsInWeek) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        HStack {
                            Text("Day \(session.dayNumber)")
                                .bold()
                                .frame(width: 60, alignment: .leading)
                            Text(session.title)
                        }
                    }
                }
            }
        }
    }
}

struct SessionDetailView: View {
    @Bindable var session: SessionTemplate
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingExercisePicker = false
    @State private var workoutToPresent: Workout?
    @Query private var profiles: [UserProfile] // To calculate targets
    
    var body: some View {
        List {
            if let notes = session.instructions, !notes.isEmpty {
                Section(header: Text("Instructions")) {
                    Text(notes)
                }
            }
            
            Section(header: Text("Exercises")) {
                if session.exercises.isEmpty {
                    Text("No exercises planned.")
                        .italic()
                        .foregroundColor(.secondary)
                } else {
                    let exercises = session.exercises.sorted { $0.orderIndex < $1.orderIndex }
                    ForEach(exercises) { templateExercise in
                        TemplateExerciseRow(templateExercise: templateExercise)
                    }
                    .onDelete(perform: deleteTemplateExercise)
                }
                
                Button("Add Exercise") {
                    showingExercisePicker = true
                }
            }
        }
        .navigationTitle(session.title)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: startWorkoutFromSession) {
                    Text("Start This Workout")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.exercises.isEmpty)
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { selectedExercise in
                addExerciseToSession(selectedExercise)
            }
        }
        .fullScreenCover(item: $workoutToPresent) { workout in
            WorkoutSessionView(workout: workout)
        }
    }
    
    private func addExerciseToSession(_ exercise: Exercise) {
        let count = session.exercises.count
        let newTemplate = TemplateExercise(orderIndex: count)
        newTemplate.exercise = exercise
        newTemplate.sessionTemplate = session
        
        // Default to 3 sets of 10
        for i in 0..<3 {
            let set = TemplateSet(orderIndex: i, targetType: .reps, targetValue: "10", intensityType: .rpe, intensityValue: 8.0)
            set.templateExercise = newTemplate
            newTemplate.sets.append(set)
        }
        
        session.exercises.append(newTemplate)
    }
    
    private func deleteTemplateExercise(at offsets: IndexSet) {
        let sorted = session.exercises.sorted { $0.orderIndex < $1.orderIndex }
        for index in offsets {
            let toDelete = sorted[index]
            modelContext.delete(toDelete)
        }
    }
    
    private func startWorkoutFromSession() {
        let profile = profiles.first ?? UserProfile()
        let newWorkout = WorkoutBuilder.instantiate(session: session, profile: profile, context: modelContext)
        workoutToPresent = newWorkout
    }
}

struct TemplateExerciseRow: View {
    @Bindable var templateExercise: TemplateExercise
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(templateExercise.exercise?.name ?? "Unknown Exercise")
                .font(.headline)
            
            // Header
            HStack(spacing: 8) {
                Text("#").font(.caption).frame(width: 24)
                Text("Target (Reps/Time)").font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                Text("Intensity").font(.caption).frame(width: 90, alignment: .leading)
            }
            .foregroundColor(.secondary)
            
            ForEach(templateExercise.sets.sorted { $0.orderIndex < $1.orderIndex }) { set in
                TemplateSetRow(set: set)
            }
            .onDelete(perform: deleteSet)
            
            Button("Add Set") {
                addSet()
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
    
    private func addSet() {
        let count = templateExercise.sets.count
        let newSet = TemplateSet(orderIndex: count, targetType: .reps, targetValue: "10")
        newSet.templateExercise = templateExercise
        templateExercise.sets.append(newSet)
    }
    
    private func deleteSet(at offsets: IndexSet) {
        let sorted = templateExercise.sets.sorted { $0.orderIndex < $1.orderIndex }
        for index in offsets {
            modelContext.delete(sorted[index])
        }
    }
}

struct TemplateSetRow: View {
    @Bindable var set: TemplateSet
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Index
            Text("\(set.orderIndex + 1)")
                .frame(width: 24)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // --- TARGET COLUMN ---
            HStack(spacing: 4) {
                Menu {
                    Picker("Type", selection: $set.targetType) {
                        Text("Reps").tag(TargetType.reps)
                        Text("Range").tag(TargetType.range)
                        Text("Time").tag(TargetType.time)
                        Text("AMRAP").tag(TargetType.amrap)
                    }
                    .onChange(of: set.targetType) { _, newValue in
                        if newValue == .amrap { set.targetValue = "AMRAP" }
                        else if newValue == .time { set.targetValue = "30" }
                        else if newValue == .reps { set.targetValue = "10" }
                        else if newValue == .range { set.targetValue = "8-12" }
                    }
                } label: {
                    Image(systemName: targetIcon)
                        .font(.caption)
                        .frame(width: 20)
                }
                .buttonStyle(.borderless)
                
                if set.targetType == .amrap {
                    Text("AMRAP")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                } else {
                    TextField("Val", text: $set.targetValue)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                }
            }
            .frame(maxWidth: .infinity)
            
            // --- INTENSITY COLUMN ---
            HStack(spacing: 4) {
                Menu {
                    Picker("Intensity", selection: $set.intensityType) {
                        Text("RPE").tag(IntensityType.rpe)
                        Text("% 1RM").tag(IntensityType.percent1RM)
                        Text("LW +").tag(IntensityType.lastWeekPlus)
                        Text("LS +").tag(IntensityType.lastSessionPlus)
                        Text("None").tag(IntensityType.none)
                    }
                } label: {
                    Text(intensityLabel)
                        .font(.caption2)
                        .bold()
                        .frame(width: 35)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                
                if set.intensityType == .none {
                    Text("-")
                        .frame(width: 45)
                        .foregroundColor(.secondary)
                } else {
                    TextField("0", value: $set.intensityValue, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .frame(width: 45)
                }
            }
            .frame(width: 90)
        }
        .padding(.vertical, 2)
    }
    
    var targetIcon: String {
        switch set.targetType {
        case .reps: return "number"
        case .range: return "arrow.left.and.right"
        case .time: return "stopwatch"
        case .amrap: return "infinity"
        }
    }
    
    var intensityLabel: String {
        switch set.intensityType {
        case .rpe: return "RPE"
        case .percent1RM: return "%"
        case .lastWeekPlus: return "LW+"
        case .lastSessionPlus: return "LS+"
        case .none: return "-"
        }
    }
}

// Keeping ProgramEditSheet and CreateProgramView largely similar but updating to SessionTemplate
struct ProgramEditSheet: View {
    @Bindable var program: Program
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String
    @State private var description: String
    @State private var weeks: Int
    @State private var sessions: Int
    
    init(program: Program) {
        self.program = program
        _name = State(initialValue: program.name)
        _description = State(initialValue: program.programDescription)
        _weeks = State(initialValue: program.durationWeeks)
        _sessions = State(initialValue: program.sessionsPerWeek)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Program Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Structure")) {
                    Stepper("Duration: \(weeks) Weeks", value: $weeks, in: 1...24)
                    Stepper("Frequency: \(sessions) / Week", value: $sessions, in: 1...7)
                }
                
                Section(footer: Text("Changing structure adds/removes days.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Edit Program")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { saveChanges() } }
            }
        }
    }
    
    private func saveChanges() {
        program.name = name
        program.programDescription = description
        
        program.durationWeeks = weeks
        program.sessionsPerWeek = sessions
        
        // Add needed sessions
        for w in 1...weeks {
            for s in 1...sessions {
                let exists = program.sessions.contains { $0.weekNumber == w && $0.dayNumber == s }
                if !exists {
                    let newSession = SessionTemplate(weekNumber: w, dayNumber: s, title: "Day \(s)")
                    newSession.program = program
                    program.sessions.append(newSession)
                }
            }
        }
        
        // Remove out of bounds sessions
        let toRemove = program.sessions.filter { $0.weekNumber > weeks || $0.dayNumber > sessions }
        for session in toRemove {
            modelContext.delete(session)
            if let index = program.sessions.firstIndex(of: session) {
                program.sessions.remove(at: index)
            }
        }
        
        dismiss()
    }
}

struct CreateProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var weeks = 4
    @State private var sessions = 3
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Program Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Structure")) {
                    Stepper("Duration: \(weeks) Weeks", value: $weeks, in: 1...24)
                    Stepper("Frequency: \(sessions) / Week", value: $sessions, in: 1...7)
                }
            }
            .navigationTitle("New Program")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { createProgram() } }
            }
        }
    }
    
    private func createProgram() {
        let newProgram = Program(name: name, programDescription: description, durationWeeks: weeks, sessionsPerWeek: sessions, isActive: true)
        
        for w in 1...weeks {
            for d in 1...sessions {
                let session = SessionTemplate(weekNumber: w, dayNumber: d, title: "Day \(d)")
                session.program = newProgram
                newProgram.sessions.append(session)
            }
        }
        
        modelContext.insert(newProgram)
        dismiss()
    }
}
