# BUFÓN - Flutter MVP

Layer 0 (Core Multiplayer MVP) for BUFÓN party game.

## Features Implemented

✅ **Core Models**: Player, Room, Question, GamePhase  
✅ **Firebase Integration**: Firestore + Anonymous Auth  
✅ **State Management**: Riverpod 2.0  
✅ **6 Core Screens**:
  - HomeScreen: Create/Join room
  - LobbyScreen: Wait for players, show room code
  - GameScreen: Answer questions with timer
  - VotingScreen: Vote on anonymous answers
  - RoundResultScreen: Show round winner and scoreboard
  - FinalWinnerScreen: Show overall winner

✅ **Game Logic**:
  - Room creation with 6-character codes
  - Real-time multiplayer sync via Firestore
  - 5 rounds × 90 seconds each
  - Voting system (can't vote for self)
  - Scoring: 100 points per vote
  - Question selection from local JSON

✅ **20 Questions** across 3 packs:
  - DI LA NETA
  - ¿QUÉ PEDO?
  - ALGUIEN DE AQUÍ

## Quick Start

### Prerequisites
- Flutter 3.8+
- iOS Simulator or Android Emulator

### Run the App

```bash
cd bufon_flutter
flutter pub get
flutter run
```

### Test Multiplayer

1. Run on 2+ devices/simulators
2. Player 1: Create room, copy code
3. Player 2+: Join with code
4. Start game when 3+ players joined

## Project Structure

```
lib/
├── main.dart                 # App entry + Firebase config
├── models/                   # Data models
│   ├── game_phase.dart
│   ├── player.dart
│   ├── question.dart
│   └── room.dart
├── services/                 # Business logic
│   ├── firebase_service.dart
│   └── question_service.dart
├── providers/                # Riverpod state management
│   └── game_providers.dart
└── screens/                  # UI screens
    ├── home_screen.dart
    ├── lobby_screen.dart
    ├── game_screen.dart
    ├── voting_screen.dart
    ├── round_result_screen.dart
    └── final_winner_screen.dart
```

## Code Stats

- **Total Lines**: ~1,800 (well under 2,000 target)
- **Files**: 13 core files
- **No animations**: Pure functionality
- **No monetization**: MVP only

## Testing Checklist

- [ ] Create room works
- [ ] Join room works
- [ ] Room code copies
- [ ] 3+ players join
- [ ] Game starts
- [ ] Timer works
- [ ] Answers submit
- [ ] Voting works
- [ ] Scores calculate
- [ ] Rounds progress
- [ ] Winner shown
- [ ] Exit works

This is **Layer 0 MVP** - focus on stability and playability, not polish.

