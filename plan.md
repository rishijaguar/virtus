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
*   [x] Set up SwiftData Schema (clean up boilerplate).
*   [x] Create core Models (`Exercise`, `Program`, `Workout`, `UserProfile`).
*   [x] Build the basic App Shell (TabView).

### Phase 2: The Logger (CRUD)
*   [x] **Exercise Manager:** Seed DB, list view, search.
*   [x] **Workout Session UI:** Interface to add exercises and log sets active/live.
*   [x] **History View:** View past workouts.

### Phase 3: The Coach (Intelligence)
*   [ ] **Chat Interface:** Chat UI bubble (UI done, logic pending).
*   [ ] **LLM Integration:** Connect to Cloud API (Gemini).
*   [ ] **Context Injection:** Feed `UserProfile` and `WorkoutHistory` to the LLM.
*   [ ] **Tool Use:** Enable LLM to return structured JSON for "Suggested Changes".

### Phase 4: Program Management
*   [x] **Program Browser/Viewer:** UI to view the current schedule.
*   [x] **Program Creation:** Manual creation and editing of structure.
*   [x] **Template Control:** Granular control over sets, reps (Ranges, AMRAP, Time), and intensity (RPE, %1RM).
*   [ ] **Onboarding Flow:** First-run experience where Coach generates Program #1.

## 6. User Directives & Preferences
*   **Style:** Native iOS look and feel (SwiftUI).
*   **Philosophy:** The app should have an "opinionated voice" favoring structure, but allow flexibility.
*   **Safety:** Coach actions regarding data modification must always be explicit (Suggest/Accept).
*   **One-off Workouts:** Supported; can serve as seeds for new programs.

---

## 7. Progress Log
*   **Infrastructure:** Established robust SwiftData schema including `Exercise`, `Program`, `ProgramDay`, `PlannedExercise`, `PlannedSet`, `Workout`, `WorkoutSet`, and `UserProfile`.
*   **Exercise Database:** Implemented a JSON-backed seeder (`exercises.json`) that populates the database on app launch. Added an Exercise List view with search.
*   **Workout Logger:** Created a fully functional active session logger (`WorkoutSessionView`) capable of recording weight, reps, and RPE. Supports "Add Set" and completion toggles.
*   **Program Management:** Built a comprehensive Program Creator (`ProgramViews`) allowing users to define duration (weeks), frequency (days/week), and detailed exercise templates.
    *   Added support for complex programming (Reps vs Time vs AMRAP, RPE vs %1RM).
    *   Implemented "Start Workout from Template" logic that copies planned sets to the active logger.
*   **History:** Implemented a History view to review completed workouts.
*   **Coach UI:** Built the basic Chat interface and Profile view.

## 8. Lessons Learned
*   **SwiftData Seeding:** Triggering an async seed task inside a lazy `sharedModelContainer` closure is unreliable. **Solution:** Move seeding logic to a `.task` on `ContentView`.
*   **Bundle Resources:** When adding external files (like `exercises.json`) to an Xcode project, they must be explicitly added to the "Target Membership" or they won't be copied to the bundle, causing file-not-found errors at runtime.
*   **SwiftUI Lists & Buttons:** Placing a standard `Button` inside a `List` row causes the entire row to become tappable (hijacking the touch target). **Solution:** Always use `.buttonStyle(.borderless)` for buttons inside List rows to isolate their tap area.
*   **Compiler Timeouts:** Deeply nested `List`/`Section`/`ForEach` with local logic triggers compiler errors. **Solution:** Extract complex sub-views (like a Week section) into their own `struct` views to simplify the AST for the compiler.
*   **Model Complexity:** Changing the data model (e.g., moving from `targetSets: Int` to `sets: [PlannedSet]`) requires careful migration of UI logic and awareness that existing simulator data might need a wipe.
*   **Complex Binding:** SwiftUI's `$set.property` binding fails in deep loops inside a `List`. **Solution:** Extract sub-rows into separate `struct` views using `@Bindable`.
*   **Intensity Logic:** Calculating targets requires a "Builder" service that has access to both the `UserProfile` (for 1RM) and the `ModelContext` (for History).
*   **Unit Safety:** For power users, storing weight as a raw `Double` requires an accompanying `WeightUnit` flag to ensure "LS + 5" logic converts correctly if the user switches from KG to LBS.