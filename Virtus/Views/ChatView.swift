//
//  ChatView.swift
//  Virtus
//
//  Created by Virtus AI on 12/21/25.
//

import SwiftUI
import SwiftData

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hello! I'm your Virtus Coach. Tell me, what is your main fitness goal right now?", isUser: false)
    ]
    @State private var inputText = ""
    @State private var isWaiting = false
    
    private let geminiService = GeminiService()
    
    public init() {}
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(AnyHashable(message.id))
                            }
                            
                            if isWaiting {
                                TypingIndicator()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(AnyHashable("waiting"))
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages) { oldValue, newValue in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: isWaiting) { oldValue, newValue in
                        if newValue {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                
                // Input Area
                HStack(spacing: 12) {
                    TextField("Message Coach...", text: $inputText, axis: .vertical)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...5)
                        .disabled(isWaiting)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(inputText.isEmpty || isWaiting ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isWaiting)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        let lastId = isWaiting ? AnyHashable("waiting") : AnyHashable(messages.last?.id)
        withAnimation {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
    
    private func sendMessage() {
        let text = inputText
        let userMessage = ChatMessage(text: text, isUser: true)
        messages.append(userMessage)
        inputText = ""
        
        Task {
            await processUserMessage(text)
        }
    }
    
    private func processUserMessage(_ text: String) async {
        isWaiting = true
        
        let systemPrompt = buildSystemPrompt()
        let history = messages.dropLast().map { GeminiRequest.Content(role: $0.isUser ? "user" : "model", parts: [GeminiRequest.Content.Part(text: $0.text)]) }
        let currentMessage = GeminiRequest.Content(role: "user", parts: [GeminiRequest.Content.Part(text: text)])
        
        do {
            let llmResponse = try await geminiService.sendMessageReturningJSON(messages: history + [currentMessage], systemPrompt: systemPrompt)
            
            let coachMessage = ChatMessage(text: llmResponse.message, isUser: false)
            messages.append(coachMessage)
            
            if let actions = llmResponse.actions {
                handleCoachActions(actions)
            }
            
        } catch {
            let errorMessage = ChatMessage(text: "Sorry, I'm having trouble connecting. \(error.localizedDescription)", isUser: false)
            messages.append(errorMessage)
        }
        
        isWaiting = false
    }

    private func handleCoachActions(_ actions: [CoachAction]) {
        guard let profile = userProfile else { return }
        
        for action in actions {
            switch action {
            case .updateProfile(let payload):
                if let goals = payload.goals { profile.goals = goals }
                if let injuries = payload.injuries { profile.injuries = injuries }
                if let preferences = payload.preferences { profile.preferences = preferences }
                
            case .proposeProgramChange(let payload):
                // For now, we just log this. In Phase 4, we'll show a UI for "Accept/Reject"
                print("Coach proposed a program change: \(payload.suggestedChanges)")
                profile.coachNotes += "\n[Proposed Change]: \(payload.suggestedChanges)"
            }
        }
        
        try? modelContext.save()
    }
    
    private func buildSystemPrompt() -> String {
        let name = userProfile?.name ?? "Athlete"
        let goals = userProfile?.goals ?? "None set"
        let injuries = userProfile?.injuries ?? "None reported"
        let preferences = userProfile?.preferences ?? "None"
        
        var prompt = """
        You are the Virtus Coach, an elite-level AI strength and conditioning coach.
        You must communicate with the user and occasionally perform actions on their profile.
        
        USER PROFILE:
        - Name: \(name)
        - Goals: \(goals)
        - Injuries: \(injuries)
        - Preferences: \(preferences)
        
        CONVERSATION STYLE:
        - Professional, encouraging, and highly knowledgeable.
        - Be concise.
        
        RESPONSE FORMAT:
        You must ALWAYS respond in valid JSON. The JSON structure is:
        {
          "message": "Your text response to the user here",
          "actions": [
            {
              "updateProfile": {
                "goals": "new goal string",
                "injuries": "new injury string",
                "preferences": "new preference string"
              }
            },
            {
              "proposeProgramChange": {
                "message": "Description of why the change is needed",
                "suggestedChanges": "Detailed description of the sets/reps/exercises to change"
              }
            }
          ]
        }
        
        - Only include the "actions" array if you are actually changing something.
        - If the user tells you about a new injury or goal, use the "updateProfile" action.
        - "message" is required.
        
        """
        
        let lastWorkouts = workouts.prefix(5)
        if !lastWorkouts.isEmpty {
            prompt += "\nRECENT WORKOUT HISTORY:\n"
            for workout in lastWorkouts {
                let dateStr = workout.startTime.formatted(date: .abbreviated, time: .omitted)
                prompt += "- \(dateStr): \(workout.exercises.count) exercises performed.\n"
                for ex in workout.exercises {
                    let exName = ex.exercise?.name ?? "Unknown"
                    let setsStr = ex.sets.map { "\($0.reps ?? 0) reps @ \($0.weight ?? 0)\($0.unitRaw)" }.joined(separator: ", ")
                    prompt += "  * \(exName): \(setsStr)\n"
                }
            }
        }
        
        return prompt
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(.systemGray3))
                    .frame(width: 8, height: 8)
                    .opacity(index < dotCount ? 1 : 0.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .cornerRadius(20)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}


struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(20)
                .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
}

#Preview {
    ChatView()
}
