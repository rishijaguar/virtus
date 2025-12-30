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
    
    public init() {}
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages) { oldValue, newValue in
                        if let lastId = newValue.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
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
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func sendMessage() {
        let text = inputText
        let userMessage = ChatMessage(text: text, isUser: true)
        messages.append(userMessage)
        inputText = ""
        
        // Mock "Agent" Logic
        processUserMessage(text)
    }
    
    private func processUserMessage(_ text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Simple keyword detection to simulate "Understanding"
            // In the real app, this would be the LLM response parsing tool calls
            
            if text.lowercased().contains("goal") || text.lowercased().contains("want to") {
                updateGoal(text)
            } else if text.lowercased().contains("injury") || text.lowercased().contains("hurt") || text.lowercased().contains("pain") {
                updateInjury(text)
            } else {
                let response = ChatMessage(text: "That's interesting. Tell me more about your goals or any injuries I should know about.", isUser: false)
                messages.append(response)
            }
        }
    }
    
    private func updateGoal(_ text: String) {
        guard let profile = userProfile else { return }
        
        // In a real app, the LLM would extract the specific goal string.
        // Here we just save the whole sentence for the demo.
        profile.goals = text
        
        let response = ChatMessage(text: "Understood. I've updated your profile with that goal: \"\(text)\"", isUser: false)
        messages.append(response)
        
        try? modelContext.save()
    }
    
    private func updateInjury(_ text: String) {
        guard let profile = userProfile else { return }
        
        profile.injuries = text
        
        let response = ChatMessage(text: "I've noted that injury. We'll be careful. Updated profile: \"\(text)\"", isUser: false)
        messages.append(response)
        
        try? modelContext.save()
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
