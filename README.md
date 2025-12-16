# 🎮 Decentralized Kahoot

A blockchain-based implementation of an interactive quiz platform inspired by Kahoot!, built using the **Move** programming language. This project brings the engaging quiz experience of Kahoot! to a decentralized environment, ensuring transparency, immutability, and trustless gameplay.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Move](https://img.shields.io/badge/language-Move-orange.svg)](https://github.com/move-language/move)

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Building the Project](#building-the-project)
- [Usage](#-usage)
- [Testing](#-testing)
- [Project Structure](#-project-structure)
- [Move Language](#-move-language)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [Security](#-security)
- [License](#-license)
- [Acknowledgments](#-acknowledgments)

---

## 🔍 Overview

**Decentralized Kahoot** reimagines the popular quiz platform as a blockchain application, leveraging the security and safety guarantees of the Move programming language. Unlike traditional centralized quiz platforms, this implementation ensures:

- **Transparency**: All quiz logic and scoring is verifiable on-chain
- **Immutability**: Quiz results cannot be tampered with after submission
- **Trustless Operation**: No central authority needed to manage games
- **Fair Play**: Cryptographic guarantees prevent cheating

This is an **experimental project** exploring how interactive educational applications can benefit from blockchain technology. It is **not affiliated** with Kahoot AS or the official Kahoot! platform.

---

## ✨ Features

### Core Functionality
- 🎯 **Quiz Creation**: Define questions, answers, and time limits on-chain
- 👥 **Multiplayer Support**: Multiple participants can join and compete in real-time
- ⏱️ **Timed Questions**: Configurable time limits for each question
- 🏆 **Scoring System**: Points awarded based on correctness and speed
- 📊 **Leaderboard**: Transparent, tamper-proof rankings
- 🔐 **Access Control**: Quiz hosts can manage participation

### Blockchain Benefits
- **Verifiable Results**: All answers and scores recorded on-chain
- **Censorship Resistance**: Quizzes cannot be removed or altered arbitrarily
- **Provable Fairness**: Scoring algorithms are public and auditable
- **Resource Safety**: Move's type system prevents common smart contract vulnerabilities

---

## 🏗️ Architecture

The project is structured around Move modules that handle different aspects of the quiz system:

### Core Modules

```
sources/
├── quiz.move          # Main quiz logic and state management
├── question.move      # Question structure and validation
├── participant.move   # Player registration and tracking
├── scoring.move       # Point calculation and leaderboard
└── access.move        # Permission and access control
```

### Key Concepts

**Quiz Object**: Represents a complete quiz session with questions, participants, and state

**Question Structure**: Stores question text, possible answers, correct answer, and time limit

**Participant Registry**: Tracks registered players and their submission status

**Scoring Engine**: Calculates points based on correctness and response time

**State Management**: Handles quiz lifecycle (created → active → completed)

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Move CLI**: Install from your target blockchain platform
  - For **Sui**: `cargo install --git https://github.com/MystenLabs/sui.git sui`
  - For **Aptos**: `cargo install --git https://github.com/aptos-labs/aptos-core.git aptos`
- **Rust**: Version 1.70.0 or higher (required for Move tools)
- **Git**: For cloning the repository

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Iwetan77/Kahoot.git
   cd Kahoot
   ```

2. **Verify Move installation**
   ```bash
   # For Sui
   sui --version
   
   # For Aptos
   aptos --version
   ```

3. **Install dependencies** (if any)
   ```bash
   # Dependencies are defined in Move.toml
   # They will be automatically fetched during build
   ```

### Building the Project

Build the Move modules:

```bash
# For Sui blockchain
sui move build

# For Aptos blockchain
aptos move compile
```

If the build is successful, you should see compiled bytecode in the `build/` directory.

---

## 💻 Usage

### Creating a Quiz

```move
// Example: Create a new quiz
public entry fun create_quiz(
    host: &signer,
    title: vector<u8>,
    description: vector<u8>,
) {
    // Implementation creates a new quiz object
}
```

### Adding Questions

```move
// Example: Add a question to a quiz
public entry fun add_question(
    host: &signer,
    quiz_id: address,
    question_text: vector<u8>,
    answers: vector<vector<u8>>,
    correct_answer: u8,
    time_limit: u64,
) {
    // Implementation adds question to quiz
}
```

### Joining a Quiz

```move
// Example: Join as a participant
public entry fun join_quiz(
    participant: &signer,
    quiz_id: address,
    nickname: vector<u8>,
) {
    // Implementation registers participant
}
```

### Submitting Answers

```move
// Example: Submit an answer
public entry fun submit_answer(
    participant: &signer,
    quiz_id: address,
    question_id: u64,
    answer: u8,
) {
    // Implementation records answer and calculates score
}
```

---

## 🧪 Testing

The project includes comprehensive test suites to ensure correctness:

### Running Tests

```bash
# Run all tests
move test

# Run tests with verbose output
move test --verbose

# Run specific test module
move test --filter quiz_tests
```

### Test Coverage

Tests are located in the `tests/` directory and cover:

- ✅ Quiz creation and initialization
- ✅ Question addition and validation
- ✅ Participant registration
- ✅ Answer submission and scoring
- ✅ Edge cases and error conditions
- ✅ Access control and permissions

### Writing Tests

Example test structure:

```move
#[test_only]
module kahoot::quiz_tests {
    use kahoot::quiz;
    
    #[test]
    fun test_create_quiz() {
        // Test implementation
    }
    
    #[test]
    #[expected_failure(abort_code = ERROR_UNAUTHORIZED)]
    fun test_unauthorized_access() {
        // Test unauthorized access fails correctly
    }
}
```

---

## 📁 Project Structure

```
Kahoot/
│
├── sources/              # Move source modules
│   ├── quiz.move        # Main quiz module
│   ├── question.move    # Question handling
│   ├── participant.move # Participant management
│   ├── scoring.move     # Scoring logic
│   └── access.move      # Access control
│
├── tests/               # Test modules
│   ├── quiz_tests.move
│   ├── scoring_tests.move
│   └── integration_tests.move
│
├── Move.toml            # Package manifest
├── Move.lock            # Locked dependencies
├── .gitignore           # Git ignore rules
└── README.md            # This file
```

### Move.toml Configuration

The `Move.toml` file defines package metadata and dependencies:

```toml
[package]
name = "Kahoot"
version = "0.1.0"

[dependencies]
# Define your Move framework dependencies here
# Example for Sui:
# Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/mainnet" }

[addresses]
kahoot = "0x0"  # Will be assigned during deployment
```

---

## 📚 Move Language

### What is Move?

[Move](https://github.com/move-language/move) is a programming language for writing safe smart contracts, originally developed by Meta (Facebook) for the Diem blockchain. It is now used by multiple blockchain platforms including Sui and Aptos.

### Key Features

- **Resource-Oriented**: Digital assets are first-class citizens
- **Type Safety**: Strong static typing prevents common bugs
- **Formal Verification**: Mathematical proof of correctness
- **Linear Types**: Resources cannot be duplicated or lost
- **Module System**: Organized, reusable code structure

### Learning Resources

- [Move Book](https://move-language.github.io/move/)
- [Move Tutorial](https://github.com/move-language/move/tree/main/language/documentation/tutorial)
- [Sui Move by Example](https://examples.sui.io/)
- [Aptos Move Guide](https://aptos.dev/move/move-on-aptos)

---

## 🗺️ Roadmap

### Phase 1: Core Functionality ✅
- [x] Basic quiz creation
- [x] Question management
- [x] Participant registration
- [x] Answer submission
- [x] Scoring system

### Phase 2: Enhanced Features 🚧
- [ ] Multiple choice question types
- [ ] True/False questions
- [ ] Picture-based questions
- [ ] Custom quiz themes
- [ ] Quiz templates

### Phase 3: Advanced Features 📋
- [ ] Team-based quizzes
- [ ] Tournament mode
- [ ] NFT rewards for winners
- [ ] Quiz marketplace
- [ ] Analytics and insights

### Phase 4: Platform Integration 🔮
- [ ] Web frontend interface
- [ ] Mobile applications
- [ ] WebSocket real-time updates
- [ ] Social features and sharing
- [ ] Integration with educational platforms

---

## 🤝 Contributing

Contributions are welcome! This is an open-source project and we appreciate community involvement.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
   - Write clean, documented code
   - Add tests for new functionality
   - Follow Move best practices
4. **Run tests**
   ```bash
   move test
   ```
5. **Commit your changes**
   ```bash
   git commit -m "Add amazing feature"
   ```
6. **Push to your fork**
   ```bash
   git push origin feature/amazing-feature
   ```
7. **Open a Pull Request**

### Contribution Guidelines

- Write clear commit messages
- Document all public functions
- Maintain test coverage above 80%
- Follow the existing code style
- Update README for significant changes

### Code Review Process

All submissions require review. We use GitHub pull requests for this purpose. Consult the [GitHub Help](https://help.github.com/articles/about-pull-requests/) for more information.

---

## 🔒 Security

### Reporting Vulnerabilities

If you discover a security vulnerability, please do **NOT** open a public issue. Instead:

1. Email the maintainers directly
2. Provide a detailed description of the vulnerability
3. Include steps to reproduce if possible
4. Allow time for a fix before public disclosure

### Security Considerations

This project is experimental and should **not** be used in production without thorough auditing. Move provides strong safety guarantees, but:

- Smart contract logic should be formally verified
- Economic incentives should be carefully designed
- Access control must be thoroughly tested
- Integration points need security review

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 Iwetan77

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

---

## 🙏 Acknowledgments

- **Kahoot!** - For the inspiration behind this educational quiz platform
- **Move Language** - For providing a secure smart contract language
- **Sui/Aptos Communities** - For tools, documentation, and support
- **Contributors** - Everyone who has contributed to this project

### Related Projects

- [ClassQuiz](https://github.com/mawoka-myblock/ClassQuiz) - Open-source Kahoot alternative
- [Quizizz](https://quizizz.com/) - Another quiz platform
- [Move Language](https://github.com/move-language/move) - The Move programming language

---

## 📞 Contact & Support

- **Issues**: [GitHub Issues](https://github.com/Iwetan77/Kahoot/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Iwetan77/Kahoot/discussions)
- **Pull Requests**: [GitHub PRs](https://github.com/Iwetan77/Kahoot/pulls)

---

## ⚠️ Disclaimer

This project is:
- **NOT** affiliated with Kahoot AS
- **NOT** production-ready without audits
- **EXPERIMENTAL** in nature
- Provided **AS-IS** without warranty

Use at your own risk. Always conduct thorough security audits before deploying smart contracts to mainnet.

---

<div align="center">

**⭐ Star this repository if you find it interesting!**

Made with ❤️ using Move

</div>
