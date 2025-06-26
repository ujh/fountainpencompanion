# Agent Tests

This directory contains tests for AI agents used in the Fountain Pen Companion application.

## PenAndInkSuggester Tests

The `PenAndInkSuggester` agent uses OpenAI's GPT to suggest fountain pen and ink combinations based on user preferences and usage history.

### Testing Philosophy

These tests follow best practices by:

- **Testing the public interface** instead of private methods
- **Mocking external HTTP requests** rather than internal implementation details
- **Verifying behavior** rather than implementation specifics
- **Using WebMock** to stub OpenAI API calls for predictable, fast tests

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
- ✅ Tests response parsing and error handling
- ✅ Avoids flaky tests from network issues
- ✅ Provides fast, predictable test execution

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

# Run with detailed output
docker-compose exec app bundle exec rspec spec/agents/pen_and_ink_suggester_spec.rb --format documentation

# Run specific test scenarios
docker-compose exec app bundle exec rspec spec/agents/pen_and_ink_suggester_spec.rb -e "excludes currently inked pens"
```

### Test Structure

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

### Dependencies

- **WebMock**: HTTP request stubbing
- **FactoryBot**: Test data creation
- **RSpec**: Testing framework
- **Docker**: Consistent test environment

### Best Practices Demonstrated

1. **No Private Method Testing**: Only tests public interface
2. **Minimal Mocking**: Only mocks external HTTP dependencies
3. **Behavior Testing**: Verifies what the agent does, not how
4. **Integration Focus**: Tests real interactions with database and HTTP
5. **Clear Test Names**: Descriptive scenario-based test descriptions
6. **Realistic Data**: Uses factories to create realistic test scenarios

### Notes

- Tests must be run via Docker using `docker-compose exec app bundle exec rspec`
- Database connection is required for ActiveRecord dependencies
- PostgreSQL database setup is handled by Docker
- WebMock prevents actual HTTP requests during testing
- All test data is created using FactoryBot factories
- The agent uses the Raix gem for AI function calling integration
