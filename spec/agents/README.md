# Agent Tests

This directory contains tests for AI agents used in the Fountain Pen Companion application.

## PenAndInkSuggester Tests

The `PenAndInkSuggester` agent uses OpenAI's GPT to suggest fountain pen and ink combinations based on user preferences and usage history.

## SpamClassifier Tests

The `SpamClassifier` agent uses OpenAI's gpt-4.1-mini to classify user accounts as spam or legitimate based on email, name, blurb, and timezone patterns compared to existing spam and normal account examples.

## InkClusterer Tests

The `InkClusterer` agent uses OpenAI's GPT-4.1 to analyze ink micro clusters and make clustering decisions based on similarity, brand information, and existing cluster data.

### InkClusterer Test Coverage

The test suite (`ink_clusterer_spec.rb`) covers:

#### Initialization & Setup

- Agent creation with micro cluster for analysis
- Agent log creation and persistence with optional agent_log_id
- System directive initialization with clustering instructions
- Transcript management with micro cluster data and processed tries

#### OpenAI Integration

- **HTTP Request Validation**: Ensures correct data is sent to OpenAI API
- **Response Handling**: Tests all clustering action responses (assign, create, ignore, hand over)
- **Error Handling**: API failures, malformed responses, unexpected formats
- **Model Configuration**: Verifies use of gpt-4.1 model
- **Function Definitions**: Validates all required clustering functions are included

#### Clustering Actions & Functions

- **Assign to Cluster**: `assign_to_cluster` function with cluster validation and explanation
- **Create New Cluster**: `create_new_cluster` function with explanation requirement
- **Ignore Ink**: `ignore_ink` function for custom mixes and invalid inks
- **Hand Over to Human**: `hand_over_to_human` function for uncertain cases
- **Brand Validation**: `known_brand` function to check if ink brands exist in database

#### Data Generation & Processing

- **Micro Cluster Data**: JSON formatting of cluster information for AI analysis
- **Color Information**: Includes/excludes color data based on availability
- **Names Processing**: Handles ink names and name elements for clustering decisions
- **Special Characters**: Manages quotes, commas, and symbols in ink names
- **Processed Tries**: Tracks and reports previous rejected clustering attempts

#### Business Logic Validation

- **Cluster Assignment**: Correctly assigns micro clusters to existing macro clusters
- **New Cluster Creation**: Creates new macro clusters when no suitable match exists
- **Ink Ignoring**: Properly ignores custom mixes and invalid inks
- **Human Handover**: Escalates uncertain cases to human review
- **Follow-up Scheduling**: Uses Sidekiq job expectations to verify job scheduling for follow-up agents

#### State Management & Workflow

- **Agent Log Updates**: Tracks clustering decisions and explanations
- **State Transitions**: Manages processing to waiting-for-approval states
- **Approval Process**: Handles approve/reject workflows with database updates
- **Cleanup Logic**: Properly reverses approved actions when rejected
- **Reprocessing**: Returns affected clusters for reprocessing after rejections
- **Job Scheduling**: Uses Sidekiq job expectations to verify background jobs are properly enqueued

### SpamClassifier Test Coverage

The test suite (`spam_classifier_spec.rb`) covers:

#### Initialization & Setup

- Agent creation with target user for classification
- Agent log creation and persistence
- System prompt initialization with spam detection instructions

#### OpenAI Integration

- **HTTP Request Validation**: Ensures correct data is sent to OpenAI API
- **Response Handling**: Tests spam and normal classification responses
- **Error Handling**: API failures, malformed responses, unexpected formats
- **Model Configuration**: Verifies use of gpt-4.1-mini model

#### Data Generation & CSV Formatting

- **Training Data**: Provides spam and normal account examples in CSV format
- **Data Limits**: Respects 50-account limits for both spam and normal examples
- **User Filtering**: Excludes users with `review_blurb: true`
- **Empty Blurb Handling**: Excludes normal users with empty blurbs from training data
- **Special Characters**: Handles quotes, commas, and special characters in user data
- **Randomization**: Shuffles normal accounts for varied training examples

#### Classification Functions

- **Spam Classification**: `classify_as_spam` function with explanation
- **Normal Classification**: `classify_as_normal` function with explanation
- **Function Parameters**: Validates explanation_of_action parameter
- **State Management**: Updates agent log with classification results

#### Business Logic Validation

- **Spam Detection**: Correctly identifies and stores spam classifications
- **Normal Classification**: Properly handles legitimate user classifications
- **Explanation Storage**: Captures reasoning for classification decisions
- **Agent State**: Sets state to "waiting-for-approval" after classification

### Testing Philosophy

These tests follow best practices by:

- **Testing the public interface** instead of private methods
- **Mocking external HTTP requests** rather than internal implementation details
- **Verifying behavior** rather than implementation specifics
- **Using WebMock** to stub OpenAI API calls for predictable, fast tests
- **Using Sidekiq job expectations** instead of mocking job scheduling methods

### Test Coverage

The test suite (`pen_and_ink_suggester_spec.rb`) covers:

#### Initialization & Setup

- Agent creation with user preferences and ink filters
- Agent log creation and persistence
- Handling of optional parameters (extra user input, ink kind)

#### OpenAI Integration

- **HTTP Request Validation**: Ensures correct data is sent to OpenAI API
- **Response Handling**: Tests various OpenAI response scenarios
- **Error Handling**: API failures, malformed responses, invalid suggestions
- **Data Filtering**: Verifies only relevant pens and inks are included

#### Data Generation & Filtering

- **CSV Format**: Validates pen and ink data is properly formatted for AI
- **Active Items Only**: Ensures archived pens/inks are excluded
- **Currently Inked Exclusion**: Prevents suggesting already-inked pens
- **Ink Kind Filtering**: Respects user's ink type preferences (bottle, cartridge, etc.)
- **Usage Statistics**: Includes usage history for AI decision-making
- **Special Characters**: Handles quotes and special characters in names

#### Business Logic Validation

- **Valid Suggestions**: Accepts correct pen and ink combinations
- **Invalid ID Handling**: Rejects suggestions with non-existent pen/ink IDs
- **Empty Suggestions**: Handles blank or missing suggestion text
- **Data Limits**: Respects LIMIT constant to avoid overwhelming the AI

#### Agent State Management

- **Agent Log Updates**: Tracks suggestions and approval state
- **Response Format**: Returns consistent response structure
- **Error Responses**: Provides user-friendly error messages

### Key Test Scenarios

1. **Happy Path**: OpenAI returns valid suggestion with existing pen and ink IDs
2. **Data Validation**: Ensures only active, available items are sent to OpenAI
3. **Error Handling**: Invalid IDs, empty suggestions, API failures
4. **Filtering Logic**: Ink kind preferences, currently inked exclusions
5. **CSV Generation**: Proper formatting for AI consumption with usage statistics

### HTTP Mocking Strategy

Tests use WebMock to stub OpenAI API requests:

```ruby
stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
  status: 200,
  body: openai_response.to_json,
  headers: {
    "Content-Type" => "application/json"
  }
)
```

This approach:

- ✅ Tests actual HTTP integration
- ✅ Validates request payloads sent to OpenAI
- ✅ Tests response parsing and error handling with specific error types
- ✅ Tests actual Sidekiq job scheduling using job expectations
- ✅ Avoids flaky tests from network issues
- ✅ Provides fast, predictable test execution

### Sidekiq Job Testing Strategy

Tests use Sidekiq's built-in testing framework to verify job scheduling:

```ruby
# Instead of mocking perform_async
expect(RunInkClustererAgent).to receive(:perform_async).with("InkClusterer", cluster.id)

# Use job expectations
expect(RunInkClustererAgent.jobs.size).to eq(1)
expect(RunInkClustererAgent.jobs.last["args"]).to eq(["InkClusterer", cluster.id])
```

This approach:

- ✅ Tests actual job scheduling without mocking
- ✅ Validates job arguments and queue state
- ✅ Uses Sidekiq's testing framework for reliability
- ✅ Automatically clears jobs between tests via `Sidekiq::Worker.clear_all`
- ✅ Supports testing multiple job scheduling scenarios
- ✅ Provides better integration testing of background job workflows

### Error Handling Testing Strategy

Tests use specific error types instead of generic error matching:

```ruby
# Instead of generic error expectation
expect { subject.perform }.to raise_error

# Use specific error types
expect { subject.perform }.to raise_error(Faraday::ServerError)
expect { subject.perform }.to raise_error(NoMethodError)
```

This approach:

- ✅ Avoids false positive warnings from RSpec
- ✅ Tests exact error conditions that should occur
- ✅ Provides more precise error handling validation
- ✅ Improves test reliability and clarity
- ✅ Follows RSpec best practices for error testing

### Request Validation

Tests verify that the correct data is sent to OpenAI:

```ruby
expect(WebMock).to have_requested(:post, openai_url).with do |req|
  body = JSON.parse(req.body)
  expect(body["model"]).to eq("gpt-4.1")
  expect(body["messages"].first["content"]).to include(pen_data)
  expect(body["messages"].first["content"]).to include(ink_data)
  true
end
```

### Response Scenarios Tested

1. **Valid Function Call**: OpenAI calls `record_suggestion` with valid IDs
2. **Invalid Pen ID**: OpenAI suggests non-existent pen
3. **Invalid Ink ID**: OpenAI suggests non-existent ink
4. **Empty Suggestion**: OpenAI returns blank suggestion text
5. **API Errors**: HTTP 500, network failures, malformed JSON
6. **Multiple Tool Calls**: Handling complex OpenAI responses

### Running the Tests

The application uses Docker for development, so tests must be run within the Docker container:

```bash
# Run all tests
docker-compose exec app bundle exec rspec

# Run all agent tests
docker-compose exec app bundle exec rspec spec/agents/

# Run only PenAndInkSuggester tests
docker-compose exec app bundle exec rspec spec/agents/pen_and_ink_suggester_spec.rb

# Run only InkClusterer tests
docker-compose exec app bundle exec rspec spec/agents/ink_clusterer_spec.rb

# Run only SpamClassifier tests
docker-compose exec app bundle exec rspec spec/agents/spam_classifier_spec.rb

# Run only CheckInkClustering tests
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/

# Run specific CheckInkClustering agent tests
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/assign_spec.rb
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/create_spec.rb
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/human_spec.rb
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/ignore_spec.rb

# Run with detailed output
docker-compose exec app bundle exec rspec spec/agents/pen_and_ink_suggester_spec.rb --format documentation

# Run specific test scenarios
docker-compose exec app bundle exec rspec spec/agents/pen_and_ink_suggester_spec.rb -e "excludes currently inked pens"
docker-compose exec app bundle exec rspec spec/agents/ink_clusterer_spec.rb -e "assigns micro cluster to macro cluster"
docker-compose exec app bundle exec rspec spec/agents/spam_classifier_spec.rb -e "classifies as spam"
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/assign_spec.rb -e "approves assignment"
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/create_spec.rb -e "rejects cluster creation for ink mixes"
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/human_spec.rb -e "sends email to human reviewer"
docker-compose exec app bundle exec rspec spec/agents/check_ink_clustering/ignore_spec.rb -e "correctly handles ink mixes"
```

#### InkClusterer Structure

```
describe InkClusterer do
  describe "#initialize" do
    # Tests agent setup and micro cluster assignment
  end

  describe "#perform" do
    context "with inks in micro cluster" do
      # Happy path clustering scenarios
    end

    context "with empty micro cluster" do
      # Edge case handling
    end

    # ... more contexts for different clustering actions
  end

  describe "function calls" do
    # Tests for assign_to_cluster, create_new_cluster, ignore_ink, etc.
  end

  describe "#approve!" do
    # Tests approval workflow and database updates
  end

  describe "#reject!" do
    # Tests rejection workflow and cleanup logic
  end

  describe "integration scenarios" do
    # End-to-end clustering workflows with processed tries
  end
end
```

### Test Structure

#### PenAndInkSuggester Structure

```
describe PenAndInkSuggester do
  describe "#initialize" do
    # Tests agent setup and configuration
  end

  describe "#perform" do
    context "when OpenAI returns valid suggestion" do
      # Happy path scenarios
    end

    context "when OpenAI returns invalid ink ID" do
      # Error handling scenarios
    end

    # ... more contexts for different scenarios
  end

  describe "data generation" do
    # CSV formatting and data filtering tests
  end

  describe "integration scenarios" do
    # End-to-end behavior with clustering data
  end
end
```

#### SpamClassifier Structure

```
describe SpamClassifier do
  describe "#initialize" do
    # Tests agent setup and user assignment
  end

  describe "#spam?" do
    # Tests classification result retrieval
  end

  describe "#perform" do
    context "when classified as spam" do
      # Spam detection scenarios
    end

    context "when classified as normal" do
      # Normal user classification scenarios
    end
  end

  describe "data formatting" do
    # CSV generation and user data filtering tests
  end

  describe "error handling" do
    # API error and malformed response scenarios
  end

  describe "integration scenarios" do
    # End-to-end classification workflows
  end
end
```

#### CheckInkClustering Structure

```
describe CheckInkClustering::[Agent] do
  describe "#initialize" do
    # Tests agent setup and micro cluster agent log assignment
  end

  describe "#perform" do
    context "when approving [action]" do
      # Happy path approval scenarios
    end

    context "when rejecting [action]" do
      # Rejection and reprocessing scenarios
    end

    context "with empty micro cluster" do
      # Edge case handling
    end

    # ... more contexts for error handling
  end

  describe "function definitions" do
    # Tests for approve/reject functions and parameters
  end

  describe "#system_directive" do
    # Tests review-specific instructions and criteria
  end

  describe "integration scenarios" do
    # End-to-end review workflows with parent agent updates
  end
end
```

### Dependencies

- **WebMock**: HTTP request stubbing
- **FactoryBot**: Test data creation
- **RSpec**: Testing framework
- **Docker**: Consistent test environment

### Testing Philosophy

These tests follow best practices by:

1. **No Private Method Testing**: Only tests public interface
2. **Minimal Mocking**: Only mocks external HTTP dependencies, uses Sidekiq job expectations
3. **Behavior Testing**: Verifies what the agent does, not how
4. **Integration Focus**: Tests real interactions with database, HTTP, and Sidekiq
5. **Clear Test Names**: Descriptive scenario-based test descriptions
6. **Realistic Data**: Uses factories to create realistic test scenarios
7. **Specific Error Testing**: Uses exact error types rather than generic error expectations

### Key InkClusterer Test Scenarios

1. **Cluster Assignment**: OpenAI calls `assign_to_cluster` with valid cluster ID and explanation
2. **New Cluster Creation**: OpenAI calls `create_new_cluster` with reasoning
3. **Ink Ignoring**: OpenAI calls `ignore_ink` for custom mixes or invalid inks
4. **Human Handover**: OpenAI calls `hand_over_to_human` for uncertain cases
5. **Brand Validation**: Uses `known_brand` function to verify ink brands exist
6. **Data Validation**: Ensures proper JSON formatting of micro cluster data
7. **Error Handling**: Invalid cluster IDs, missing explanations, API failures
8. **Approval Workflow**: Complete approve/reject cycles with database updates
9. **Processed Tries**: Handles previous rejected attempts and prevents repetition
10. **Follow-up Scheduling**: Verifies actual Sidekiq jobs are enqueued for CheckInkClustering agents

### Key InkClusterer Integration Tests

1. **Complete Clustering Workflow**: Full workflow from micro cluster analysis to follow-up job scheduling
2. **Processed Tries Integration**: Handles multiple rejected attempts with proper transcript updates
3. **Brand Validation Integration**: Uses known_brand function with database queries
4. **Similarity Search Integration**: Provides proper data formatting for AI clustering decisions
5. **Web Search Integration**: Instructions for AI to search web for ink validation
6. **State Management**: Complete approve/reject cycles with proper database cleanup
7. **Job Scheduling Integration**: Uses Sidekiq.jobs expectations to verify worker job enqueueing
8. **Special Character Handling**: Manages complex ink names with quotes and symbols
9. **Edge Cases**: Empty clusters, long names, and various data formatting scenarios

## CheckInkClustering Tests

The `CheckInkClustering` agents use OpenAI's GPT-4.1 to review clustering decisions made by the InkClusterer agent. These agents provide secondary validation of clustering, creation, ignoring, and human handover decisions.

### CheckInkClustering Agent Types

- **CheckInkClustering::Assign**: Reviews cluster assignment decisions
- **CheckInkClustering::Create**: Reviews new cluster creation decisions
- **CheckInkClustering::Ignore**: Reviews ink ignoring decisions
- **CheckInkClustering::Human**: Handles human review handovers with email notifications

### CheckInkClustering Test Coverage

The test suites (`check_ink_clustering/*_spec.rb`) cover:

#### Initialization & Setup

- Agent creation with micro cluster agent log reference
- Child agent log creation and persistence with parent relationship
- System directive initialization with review-specific instructions
- Transcript management with clustering explanations and micro cluster data
- Macro cluster data inclusion (for Assign agent)

#### OpenAI Integration

- **HTTP Request Validation**: Ensures correct data is sent to OpenAI API
- **Response Handling**: Tests approval and rejection function responses
- **Error Handling**: API failures, malformed responses, unexpected formats
- **Model Configuration**: Verifies use of gpt-4.1 model for review tasks
- **Function Definitions**: Validates all required review functions are available

#### Review Actions & Functions

- **Approve Actions**: `approve_assignment`, `approve_cluster_creation` functions with explanations
- **Reject Actions**: `reject_assignment`, `reject_cluster_creation` functions with explanations
- **Email Notifications**: `send_email` function for human reviewer notifications (Human agent)
- **Explanation Requirements**: All functions require detailed explanation_of_decision parameters

#### Business Logic Validation

- **Assignment Review**: Correctly approves/rejects cluster assignments with reasoning
- **Creation Review**: Validates new cluster creation decisions including ink mix detection
- **Ignoring Review**: Reviews decisions to ignore custom mixes, incomplete entries, non-inks
- **Human Handover**: Sends email notifications and approves parent agent logs
- **Follow-up Updates**: Properly updates parent agent logs with review decisions
- **Reprocessing Logic**: Handles rejected decisions with cluster reprocessing

#### State Management & Workflow

- **Agent Log Updates**: Tracks review decisions and explanations
- **Parent-Child Relationships**: Manages follow-up data between InkClusterer and CheckInkClustering agents
- **State Transitions**: Sets appropriate waiting-for-approval states
- **Error Propagation**: Raises specific error types (Faraday::ServerError, NoMethodError) for API failures and malformed responses
- **Integration Testing**: Complete workflows from review to final approval/rejection

#### Email Integration (Human Agent)

- **AdminMailer Integration**: Sends emails to human reviewers with case summaries
- **Email Content**: Includes clustering reasoning and ink data for human review
- **Delivery Scheduling**: Uses deliver_later for asynchronous email delivery
- **Complex Cases**: Handles non-standard ink names, special characters, and edge cases

### Key CheckInkClustering Test Scenarios

#### Assignment Review (CheckInkClustering::Assign)

1. **Correct Assignments**: Approves valid cluster assignments with explanations
2. **Incorrect Assignments**: Rejects invalid assignments and triggers reprocessing
3. **Macro Cluster Data**: Includes target cluster information for review context
4. **Empty Clusters**: Handles empty micro clusters appropriately
5. **Integration Workflow**: Complete approve/reject cycles with parent agent updates

#### Creation Review (CheckInkClustering::Create)

1. **Valid New Clusters**: Approves creation of unique ink clusters
2. **Invalid Creations**: Rejects creation for misspellings, existing inks, mixes
3. **Ink Mix Detection**: Identifies and rejects custom ink mixtures
4. **Brand Validation**: Considers known brand patterns in creation decisions
5. **Edge Cases**: Handles incomplete entries and non-ink products

#### Ignore Review (CheckInkClustering::Ignore)

1. **Valid Ignoring**: Approves ignoring of custom mixes, incomplete entries
2. **Invalid Ignoring**: Rejects ignoring of legitimate inks requiring clustering
3. **Mix Identification**: Validates decisions to ignore ink mixtures
4. **Product Classification**: Reviews decisions about non-fountain-pen products
5. **Name Completeness**: Assesses whether ink names are complete enough for clustering

#### Human Review (CheckInkClustering::Human)

1. **Email Generation**: Creates appropriate email content for human reviewers
2. **Case Summarization**: Includes clustering context and reasoning in emails
3. **Complex Cases**: Handles challenging inks with special characters or unclear names
4. **Error Handling**: Manages API failures while still processing handovers
5. **Approval Process**: Always approves parent agent after sending notifications

### Key SpamClassifier Test Scenarios

1. **Spam Classification**: OpenAI calls `classify_as_spam` with explanation
2. **Normal Classification**: OpenAI calls `classify_as_normal` with explanation
3. **Data Validation**: Ensures proper CSV formatting with spam/normal examples
4. **Filtering Logic**: Excludes inappropriate users from training data
5. **Error Handling**: Invalid responses, API failures, malformed JSON
6. **Integration Testing**: Complete classification workflows with state management

### Notes

- Tests must be run via Docker using `docker-compose exec app bundle exec rspec`
- Database connection is required for ActiveRecord dependencies
- PostgreSQL database setup is handled by Docker
- WebMock prevents actual HTTP requests during testing
- Sidekiq testing framework provides job expectations for scheduling verification
- All test data is created using FactoryBot factories
- The agents use the Raix gem for AI function calling integration
- InkClusterer uses gpt-4.1 model for complex clustering decisions
- SpamClassifier uses gpt-4.1-mini model for cost-effective spam detection
- CheckInkClustering agents use gpt-4.1 model for detailed review analysis
- InkClusterer tests include realistic ink data with brands, colors, and clustering scenarios
- Test data includes realistic spam and normal user patterns for accurate classification
- CheckInkClustering tests include realistic review scenarios with complex ink names and edge cases
- All CheckInkClustering agents include parent-child agent log relationships for proper workflow tracking
