module kahoot::quiz {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use std::string::{Self, String};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    

    // Error codes
    const E_INVALID_ANSWER: u64 = 1;
    const E_QUIZ_NOT_ACTIVE: u64 = 2;
    const E_ALREADY_COMPLETED: u64 = 3;
    const E_INSUFFICIENT_PRIZE: u64 = 4;
    const E_UNAUTHORIZED: u64 = 5;
    const E_INVALID_QUESTION_COUNT: u64 = 6;
    const E_INVALID_PRIZE_POSITIONS: u64 = 7;
    const E_QUIZ_STILL_ACTIVE: u64 = 8;

    // Constants
    const MIN_QUESTIONS: u64 = 1;
    const MAX_QUESTIONS: u64 = 50;
    const MIN_PRIZE_AMOUNT: u64 = 1000000; // 0.001 SUI in MIST
    const MAX_WINNERS: u64 = 10;

    // Question structure
    public struct Question has store, drop {
        question_text: String,
        options: vector<String>,
        correct_answer: u8, // Index of correct option (0-based)
    }

    // Prize structure for different positions
    public struct PrizeDistribution has store, drop, copy {
        position: u8, // 1st, 2nd, 3rd, etc.
        amount: u64,
    }

    // Participant submission
    public struct Submission has store, drop {
        participant: address,
        answers: vector<u8>,
        score: u8,
        completion_time: u64, // For tie-breaking
    }

    // Winner information
    public struct Winner has store, drop {
        participant: address,
        position: u8,
        score: u8,
        prize_amount: u64,
    }

    // Quiz structure
    public struct Quiz has key, store {
        id: UID,
        creator: address,
        title: String,
        description: String,
        questions: vector<Question>,
        prize_pool: Balance<SUI>,
        prize_distribution: vector<PrizeDistribution>, // How prizes are distributed
        total_prize: u64,
        is_active: bool,
        is_finalized: bool, // Whether results have been calculated
        created_at: u64,
        submissions: vector<Submission>, // All submissions
        winners: vector<Winner>, // Calculated winners
        participant_completed: Table<address, bool>, // Track who completed
    }

    // Completion certificate with ranking
    public struct CompletionCertificate has key, store {
        id: UID,
        quiz_id: address,
        quiz_title: String,
        participant: address,
        score: u8,
        final_position: Option<u8>, // Position if winner, none if not
        prize_won: u64,
        completed_at: u64,
    }

    // Quiz registry to track all quizzes
    public struct QuizRegistry has key {
        id: UID,
        quizzes: Table<address, bool>,
        quiz_count: u64,
    }

    // Initialize the module
    fun init(ctx: &mut TxContext) {
        let registry = QuizRegistry {
            id: object::new(ctx),
            quizzes: table::new(ctx),
            quiz_count: 0,
        };
        transfer::share_object(registry);
    }

    // Create a new quiz with position-based prizes
    public entry fun create_quiz(
        registry: &mut QuizRegistry,
        title: vector<u8>,
        description: vector<u8>,
        question_texts: vector<vector<u8>>,
        question_options: vector<vector<vector<u8>>>,
        correct_answers: vector<u8>,
        prize_positions: vector<u8>, // Which positions get prizes (1, 2, 3, etc.)
        prize_amounts: vector<u64>,  // Prize amounts for each position
        mut prize_coins: vector<Coin<SUI>>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let question_count = vector::length(&question_texts);
        let prize_count = vector::length(&prize_positions);
        
        // Validate inputs
        assert!(question_count >= MIN_QUESTIONS && question_count <= MAX_QUESTIONS, E_INVALID_QUESTION_COUNT);
        assert!(vector::length(&question_options) == question_count, E_INVALID_QUESTION_COUNT);
        assert!(vector::length(&correct_answers) == question_count, E_INVALID_QUESTION_COUNT);
        assert!(prize_count > 0 && prize_count <= MAX_WINNERS, E_INVALID_PRIZE_POSITIONS);
        assert!(vector::length(&prize_amounts) == prize_count, E_INVALID_PRIZE_POSITIONS);

        // Merge all prize coins
        let mut total_balance = balance::zero<SUI>();
        let mut i = 0;
        while (i < vector::length(&prize_coins)) {
            let coin = vector::pop_back(&mut prize_coins);
            balance::join(&mut total_balance, coin::into_balance(coin));
            i = i + 1;
        };
        vector::destroy_empty(prize_coins);

        // Calculate total prize needed and validate
        let mut total_prize_needed = 0u64;
        let mut prize_distribution = vector::empty<PrizeDistribution>();
        i = 0;
        while (i < prize_count) {
            let position = *vector::borrow(&prize_positions, i);
            let amount = *vector::borrow(&prize_amounts, i);
            
            assert!(position > 0 && position <= (MAX_WINNERS as u8), E_INVALID_PRIZE_POSITIONS);
            assert!(amount >= MIN_PRIZE_AMOUNT, E_INSUFFICIENT_PRIZE);
            
            total_prize_needed = total_prize_needed + amount;
            vector::push_back(&mut prize_distribution, PrizeDistribution { position, amount });
            i = i + 1;
        };

        let total_prize = balance::value(&total_balance);
        assert!(total_prize >= total_prize_needed, E_INSUFFICIENT_PRIZE);

        // Build questions
        let mut questions = vector::empty<Question>();
        let mut j = 0;
        while (j < question_count) {
            let question_text = string::utf8(*vector::borrow(&question_texts, j));
            let raw_options = *vector::borrow(&question_options, j);
            let correct_answer = *vector::borrow(&correct_answers, j);
            
            // Convert options to strings
            let mut options = vector::empty<String>();
            let mut k = 0;
            while (k < vector::length(&raw_options)) {
                vector::push_back(&mut options, string::utf8(*vector::borrow(&raw_options, k)));
                k = k + 1;
            };
            
            // Validate correct answer index
            assert!(correct_answer < (vector::length(&options) as u8), E_INVALID_ANSWER);
            
            let question = Question {
                question_text,
                options,
                correct_answer,
            };
            vector::push_back(&mut questions, question);
            j = j + 1;
        };

        // Create quiz
        let quiz_id = object::new(ctx);
        let quiz_address = object::uid_to_address(&quiz_id);
        
        let quiz = Quiz {
            id: quiz_id,
            creator: tx_context::sender(ctx),
            title: string::utf8(title),
            description: string::utf8(description),
            questions,
            prize_pool: total_balance,
            prize_distribution,
            total_prize,
            is_active: true,
            is_finalized: false,
            created_at: clock::timestamp_ms(clock),
            submissions: vector::empty<Submission>(),
            winners: vector::empty<Winner>(),
            participant_completed: table::new(ctx),
        };

        // Register quiz
        table::add(&mut registry.quizzes, quiz_address, true);
        registry.quiz_count = registry.quiz_count + 1;

        // Share the quiz object
        transfer::share_object(quiz);
    }

    // Submit quiz answers
    public entry fun submit_answers(
        quiz: &mut Quiz,
        answers: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let participant = tx_context::sender(ctx);
        
        // Check if quiz is active
        assert!(quiz.is_active, E_QUIZ_NOT_ACTIVE);
        
        // Check if user already completed
        assert!(!table::contains(&quiz.participant_completed, participant), E_ALREADY_COMPLETED);
        
        // Validate answer count
        assert!(vector::length(&answers) == vector::length(&quiz.questions), E_INVALID_ANSWER);

        // Calculate score
        let mut score = 0u8;
        let mut i = 0;
        while (i < vector::length(&answers)) {
            let user_answer = *vector::borrow(&answers, i);
            let question = vector::borrow(&quiz.questions, i);
            
            // Validate answer is within valid range
            assert!(user_answer < (vector::length(&question.options) as u8), E_INVALID_ANSWER);
            
            if (user_answer == question.correct_answer) {
                score = score + 1;
            };
            i = i + 1;
        };

        // Record submission
        let submission = Submission {
            participant,
            answers,
            score,
            completion_time: clock::timestamp_ms(clock),
        };
        
        vector::push_back(&mut quiz.submissions, submission);
        table::add(&mut quiz.participant_completed, participant, true);
    }

    // Creator finalizes quiz and calculates winners
    public entry fun finalize_quiz(quiz: &mut Quiz, ctx: &mut TxContext) {
        assert!(quiz.creator == tx_context::sender(ctx), E_UNAUTHORIZED);
        assert!(quiz.is_active, E_QUIZ_NOT_ACTIVE);
        assert!(!quiz.is_finalized, E_QUIZ_STILL_ACTIVE);

        quiz.is_active = false;
        quiz.is_finalized = true;

        // Sort submissions by score (descending) and completion time (ascending for ties)
        sort_submissions_by_score(&mut quiz.submissions);

        // Determine winners based on prize distribution
        let mut winners = vector::empty<Winner>();
        let mut position_index = 0;
        
        while (position_index < vector::length(&quiz.prize_distribution)) {
            let prize_info = vector::borrow(&quiz.prize_distribution, position_index);
            let target_position = prize_info.position;
            
            // Find participant at this position (1-indexed)
            if (target_position <= (vector::length(&quiz.submissions) as u8)) {
                let submission = vector::borrow(&quiz.submissions, (target_position as u64) - 1);
                let winner = Winner {
                    participant: submission.participant,
                    position: target_position,
                    score: submission.score,
                    prize_amount: prize_info.amount,
                };
                vector::push_back(&mut winners, winner);
            };
            position_index = position_index + 1;
        };

        quiz.winners = winners;
    }

    // Winners can claim their prizes after finalization
    public entry fun claim_prize(quiz: &mut Quiz, clock: &Clock, ctx: &mut TxContext) {
        let participant = tx_context::sender(ctx);
        
        assert!(quiz.is_finalized, E_QUIZ_STILL_ACTIVE);
        
        // Find if participant is a winner
        let mut winner_position: Option<u8> = option::none();
        let mut prize_amount = 0u64;
        let mut participant_score = 0u8;
        
        let mut i = 0;
        while (i < vector::length(&quiz.winners)) {
            let winner = vector::borrow(&quiz.winners, i);
            if (winner.participant == participant) {
                winner_position = option::some(winner.position);
                prize_amount = winner.prize_amount;
                break
            };
            i = i + 1;
        };

        // Get participant's score from submissions
        i = 0;
        while (i < vector::length(&quiz.submissions)) {
            let submission = vector::borrow(&quiz.submissions, i);
            if (submission.participant == participant) {
                participant_score = submission.score;
                break
            };
            i = i + 1;
        };

        // Transfer prize if winner
        if (option::is_some(&winner_position)) {
            let prize_balance = balance::split(&mut quiz.prize_pool, prize_amount);
            let prize_coin = coin::from_balance(prize_balance, ctx);
            transfer::public_transfer(prize_coin, participant);
        };

        // Create completion certificate
        let certificate = CompletionCertificate {
            id: object::new(ctx),
            quiz_id: object::uid_to_address(&quiz.id),
            quiz_title: quiz.title,
            participant,
            score: participant_score,
            final_position: winner_position,
            prize_won: prize_amount,
            completed_at: clock::timestamp_ms(clock),
        };

        transfer::public_transfer(certificate, participant);
    }

    // Creator can withdraw remaining prize money after finalization
    public entry fun withdraw_remaining_prize(quiz: &mut Quiz, ctx: &mut TxContext) {
        assert!(quiz.creator == tx_context::sender(ctx), E_UNAUTHORIZED);
        assert!(quiz.is_finalized, E_QUIZ_STILL_ACTIVE);
        
        let remaining_balance = balance::value(&quiz.prize_pool);
        if (remaining_balance > 0) {
            let remaining_coin = coin::from_balance(
                balance::split(&mut quiz.prize_pool, remaining_balance), 
                ctx
            );
            transfer::public_transfer(remaining_coin, quiz.creator);
        };
    }

    // Helper function to sort submissions by score (desc) and time (asc)
    fun sort_submissions_by_score(submissions: &mut vector<Submission>) {
        let len = vector::length(submissions);
        if (len <= 1) return;
        
        // Simple bubble sort for now (can be optimized)
        let mut i = 0;
        while (i < len - 1) {
            let mut j = 0;
            while (j < len - i - 1) {
                let curr = vector::borrow(submissions, j);
                let next = vector::borrow(submissions, j + 1);
                
                // Sort by score descending, then by time ascending
                let should_swap = if (curr.score < next.score) {
                    true
                } else if (curr.score == next.score) {
                    curr.completion_time > next.completion_time
                } else {
                    false
                };
                
                if (should_swap) {
                    vector::swap(submissions, j, j + 1);
                };
                j = j + 1;
            };
            i = i + 1;
        };
    }

    // View functions
    public fun get_quiz_info(quiz: &Quiz): (String, String, u64, bool, bool, u64) {
        (
            quiz.title,
            quiz.description,
            quiz.total_prize,
            quiz.is_active,
            quiz.is_finalized,
            vector::length(&quiz.submissions)
        )
    }

    public fun get_prize_distribution(quiz: &Quiz): &vector<PrizeDistribution> {
        &quiz.prize_distribution
    }

    public fun get_winners(quiz: &Quiz): &vector<Winner> {
        &quiz.winners
    }

    public fun get_question_count(quiz: &Quiz): u64 {
        vector::length(&quiz.questions)
    }

    public fun get_question(quiz: &Quiz, index: u64): (String, vector<String>) {
        let question = vector::borrow(&quiz.questions, index);
        (question.question_text, question.options)
    }

    public fun has_submitted(quiz: &Quiz, participant: address): bool {
        table::contains(&quiz.participant_completed, participant)
    }

    public fun get_remaining_prize(quiz: &Quiz): u64 {
        balance::value(&quiz.prize_pool)
    }

    public fun get_certificate_info(cert: &CompletionCertificate): (address, String, address, u8, Option<u8>, u64) {
        (cert.quiz_id, cert.quiz_title, cert.participant, cert.score, cert.final_position, cert.prize_won)
    }

    // Test helper functions
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    use sui::test_scenario;

    #[test]
    fun test_create_quiz() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Initialize the module
        init_for_testing(scenario.ctx());
        scenario.next_tx(@0x1);
        
        // Get the registry
        let mut registry = scenario.take_shared<QuizRegistry>();
        let clock = clock::create_for_testing(scenario.ctx());
        
        // Create a quiz
        let title = b"Test Quiz";
        let description = b"A test quiz";
        let question_texts = vector[b"What is 2+2?"];
        let question_options = vector[vector[b"3", b"4", b"5"]];
        let correct_answers = vector[1u8]; // Index 1 = "4"
        let prize_positions = vector[1u8]; // 1st place
        let prize_amounts = vector[1000000u64]; // 0.001 SUI
        
        // Create prize coin
        let prize_coin = coin::mint_for_testing<SUI>(1000000, scenario.ctx());
        let prize_coins = vector[prize_coin];
        
        create_quiz(
            &mut registry,
            title,
            description,
            question_texts,
            question_options,
            correct_answers,
            prize_positions,
            prize_amounts,
            prize_coins,
            &clock,
            scenario.ctx()
        );
        
        // Clean up
        test_scenario::return_shared(registry);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test]
    fun test_submit_answers() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Initialize and create quiz
        init_for_testing(scenario.ctx());
        scenario.next_tx(@0x1);
        
        let mut registry = scenario.take_shared<QuizRegistry>();
        let clock = clock::create_for_testing(scenario.ctx());
        
        let title = b"Test Quiz";
        let description = b"A test quiz";
        let question_texts = vector[b"What is 2+2?"];
        let question_options = vector[vector[b"3", b"4", b"5"]];
        let correct_answers = vector[1u8];
        let prize_positions = vector[1u8];
        let prize_amounts = vector[1000000u64];
        
        let prize_coin = coin::mint_for_testing<SUI>(1000000, scenario.ctx());
        let prize_coins = vector[prize_coin];
        
        create_quiz(
            &mut registry,
            title,
            description,
            question_texts,
            question_options,
            correct_answers,
            prize_positions,
            prize_amounts,
            prize_coins,
            &clock,
            scenario.ctx()
        );
        
        test_scenario::return_shared(registry);
        scenario.next_tx(@0x2); // Different user
        
        // Submit answers
        let mut quiz = scenario.take_shared<Quiz>();
        let answers = vector[1u8]; // Correct answer
        
        submit_answers(&mut quiz, answers, &clock, scenario.ctx());
        
        // Verify submission
        assert!(has_submitted(&quiz, @0x2));
        
        test_scenario::return_shared(quiz);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test]
    fun test_finalize_and_claim_prize() {
        let mut scenario = test_scenario::begin(@0x1);
        
        // Initialize and create quiz
        init_for_testing(scenario.ctx());
        scenario.next_tx(@0x1);
        
        let mut registry = scenario.take_shared<QuizRegistry>();
        let clock = clock::create_for_testing(scenario.ctx());
        
        let title = b"Test Quiz";
        let description = b"A test quiz";
        let question_texts = vector[b"What is 2+2?"];
        let question_options = vector[vector[b"3", b"4", b"5"]];
        let correct_answers = vector[1u8];
        let prize_positions = vector[1u8];
        let prize_amounts = vector[1000000u64];
        
        let prize_coin = coin::mint_for_testing<SUI>(1000000, scenario.ctx());
        let prize_coins = vector[prize_coin];
        
        create_quiz(
            &mut registry,
            title,
            description,
            question_texts,
            question_options,
            correct_answers,
            prize_positions,
            prize_amounts,
            prize_coins,
            &clock,
            scenario.ctx()
        );
        
        test_scenario::return_shared(registry);
        scenario.next_tx(@0x2); // User submits answer
        
        // Submit correct answer
        let mut quiz = scenario.take_shared<Quiz>();
        let answers = vector[1u8];
        submit_answers(&mut quiz, answers, &clock, scenario.ctx());
        test_scenario::return_shared(quiz);
        
        // Creator finalizes quiz
        scenario.next_tx(@0x1);
        let mut quiz = scenario.take_shared<Quiz>();
        finalize_quiz(&mut quiz, scenario.ctx());
        test_scenario::return_shared(quiz);
        
        // Winner claims prize
        scenario.next_tx(@0x2);
        let mut quiz = scenario.take_shared<Quiz>();
        claim_prize(&mut quiz, &clock, scenario.ctx());
        
        test_scenario::return_shared(quiz);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test]
    #[expected_failure(abort_code = E_ALREADY_COMPLETED)]
    fun test_duplicate_submission_fails() {
        let mut scenario = test_scenario::begin(@0x1);
        
        init_for_testing(scenario.ctx());
        scenario.next_tx(@0x1);
        
        let mut registry = scenario.take_shared<QuizRegistry>();
        let clock = clock::create_for_testing(scenario.ctx());
        
        let title = b"Test Quiz";
        let description = b"A test quiz";
        let question_texts = vector[b"What is 2+2?"];
        let question_options = vector[vector[b"3", b"4", b"5"]];
        let correct_answers = vector[1u8];
        let prize_positions = vector[1u8];
        let prize_amounts = vector[1000000u64];
        
        let prize_coin = coin::mint_for_testing<SUI>(1000000, scenario.ctx());
        let prize_coins = vector[prize_coin];
        
        create_quiz(
            &mut registry,
            title,
            description,
            question_texts,
            question_options,
            correct_answers,
            prize_positions,
            prize_amounts,
            prize_coins,
            &clock,
            scenario.ctx()
        );
        
        test_scenario::return_shared(registry);
        scenario.next_tx(@0x2);
        
        let mut quiz = scenario.take_shared<Quiz>();
        let answers = vector[1u8];
        
        // First submission should succeed
        submit_answers(&mut quiz, answers, &clock, scenario.ctx());
        
        // Second submission should fail
        submit_answers(&mut quiz, answers, &clock, scenario.ctx());
        
        test_scenario::return_shared(quiz);
        clock::destroy_for_testing(clock);
        scenario.end();
    }

    #[test]
    fun test_view_functions() {
        let mut scenario = test_scenario::begin(@0x1);
        
        init_for_testing(scenario.ctx());
        scenario.next_tx(@0x1);
        
        let mut registry = scenario.take_shared<QuizRegistry>();
        let clock = clock::create_for_testing(scenario.ctx());
        
        let title = b"Test Quiz";
        let description = b"A test quiz";
        let question_texts = vector[b"What is 2+2?"];
        let question_options = vector[vector[b"3", b"4", b"5"]];
        let correct_answers = vector[1u8];
        let prize_positions = vector[1u8];
        let prize_amounts = vector[1000000u64];
        
        let prize_coin = coin::mint_for_testing<SUI>(1000000, scenario.ctx());
        let prize_coins = vector[prize_coin];
        
        create_quiz(
            &mut registry,
            title,
            description,
            question_texts,
            question_options,
            correct_answers,
            prize_positions,
            prize_amounts,
            prize_coins,
            &clock,
            scenario.ctx()
        );
        
        test_scenario::return_shared(registry);
        scenario.next_tx(@0x1);
        
        let quiz = scenario.take_shared<Quiz>();
        
        // Test view functions
        let (quiz_title, quiz_desc, total_prize, is_active, is_finalized, submission_count) = 
            get_quiz_info(&quiz);
        
        assert!(quiz_title == string::utf8(b"Test Quiz"));
        assert!(quiz_desc == string::utf8(b"A test quiz"));
        assert!(total_prize == 1000000);
        assert!(is_active == true);
        assert!(is_finalized == false);
        assert!(submission_count == 0);
        
        assert!(get_question_count(&quiz) == 1);
        assert!(get_remaining_prize(&quiz) == 1000000);
        assert!(!has_submitted(&quiz, @0x2));
        
        let (question_text, options) = get_question(&quiz, 0);
        assert!(question_text == string::utf8(b"What is 2+2?"));
        assert!(vector::length(&options) == 3);
        
        test_scenario::return_shared(quiz);
        clock::destroy_for_testing(clock);
        scenario.end();
    }
}