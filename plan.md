# Virtus - Project Plan & North Star

## 1. Vision & Goal
Virtus is a gym logging application designed for serious lifters (weightlifters, powerlifters, bodybuilders) and anyone engaging in structured exercise. It differentiates itself from the crowded market of workout loggers by integrating an **Elite-Level AI Coach**. This coach is not a passive bot but an active, context-aware agent that understands exercise science, nutrition, and the user's specific long-term goals.

The app balances an **opinionated, structured approach** to training (Programs) with the **flexibility** required for real life (Workouts).

## 2. Target Audience
*   Powerlifters, Bodybuilders, Weightlifters.
*   Individuals who follow structured programs (e.g., "5/3/1", "Starting Strength", Hypertrophy blocks).
*   Users seeking expert guidance without the cost of a human personal trainer.

## 3. Core Features (MVP)

### A. The Gym Logger
*   **Structured Logging:** Record exercises, sets, reps, weight, time, distance, and RPE.
*   **Exercise Database:** A robust, pre-seeded database of exercises with support for user-added custom exercises.
*   **History & Stats:** view past performance to track progress over time.

### B. The AI Coach (LLM-Powered)
*   **Onboarding:** Conducts an initial interview to understand goals, experience, and equipment to generate the first program.
*   **Proactive & Reactive Guidance:**
    *   **Pre-Workout:** Checks in on user readiness (sleep, soreness) and suggests adjustments.
    *   **Post-Workout:** Asks for feedback (difficulty, pain) to refine future sessions.
*   **Program Management:** The coach creates and modifies programs.
    *   **"Suggest & Accept" Model:** The Coach proposes changes (e.g., "Swap Bench Press for Dumbbell Press due to shoulder pain?"), and the user accepts or rejects them. The AI never silently alters data.
*   **Context Awareness:** Remembers long-term facts (injuries, equipment limitations, specific goals) stored in a persistent `UserProfile`.
*   **Ad-Hoc Requests:** Can generate one-off workouts or answer general fitness/nutrition questions.

### C. Program & Workout Structure
*   **Programs:** Opinionated schedules (e.g., "4-Week Strength Block"). Contains "Program Days" (templates).
*   **Workouts:** Actual performed sessions. Can be instantiated from a Program Day or created from scratch (flexible).
*   **Progression:** Supports linear progression and other overloading schemes via the Coach's logic.

## 4. Architecture & Data Model

### Tech Stack
*   **Platform:** iOS (SwiftUI)
*   **Data Persistence:** SwiftData
*   **AI/LLM:** Cloud API (Integration TBD)

### Core Domain Models
*   **`Exercise`**: Standardized definition (Name, Muscle Group, Type).
*   **`UserProfile`**: The "Coach's Brain". Stores structured and unstructured data (Goals, Injuries, Preferences, CoachNotes).
*   **`Program`**: A scheduled collection of templates (e.g., "Week 1, Day 1").
    *   *Relationships:* Has many `ProgramDay`s.
*   **`ProgramDay`**: A template for a specific workout within a program.
    *   *Relationships:* Has many `PlannedExercise`s.
*   **`Workout`**: A record of a completed or in-progress session.
    *   *Relationships:* Has many `WorkoutExercise`s. Optional link to `ProgramDay`.
*   **`WorkoutExercise` / `WorkoutSet`**: The actual log data (weight, reps, RPE).

## 5. Development Roadmap

### Phase 1: Foundation (Current Focus)
*   [ ] Set up SwiftData Schema (clean up boilerplate).
*   [ ] Create core Models (`Exercise`, `Program`, `Workout`, `UserProfile`).
*   [ ] Build the basic App Shell (TabView).

### Phase 2: The Logger (CRUD)
*   [ ] **Exercise Manager:** Seed DB, list view, search.
*   [ ] **Workout Session UI:** Interface to add exercises and log sets active/live.
*   [ ] **History View:** View past workouts.

### Phase 3: The Coach (Intelligence)
*   [ ] **Chat Interface:** Chat UI bubble.
*   [ ] **LLM Integration:** Connect to Cloud API.
*   [ ] **Context Injection:** Feed `UserProfile` and `WorkoutHistory` to the LLM.
*   [ ] **Tool Use:** Enable LLM to return structured JSON for "Suggested Changes".

### Phase 4: Program Management
*   [ ] **Program Browser/Viewer:** UI to view the current schedule.
*   [ ] **Onboarding Flow:** First-run experience where Coach generates Program #1.

## 6. User Directives & Preferences
*   **Style:** Native iOS look and feel (SwiftUI).
*   **Philosophy:** The app should have an "opinionated voice" favoring structure, but allow flexibility.
*   **Safety:** Coach actions regarding data modification must always be explicit (Suggest/Accept).
*   **One-off Workouts:** Supported; can serve as seeds for new programs.
