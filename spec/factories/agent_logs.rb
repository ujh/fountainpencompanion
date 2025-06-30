FactoryBot.define do
  factory :agent_log do
    sequence(:name) { |n| "TestAgent#{n}" }
    transcript { [{ "role" => "system", "content" => "Test transcript for agent log" }] }
    state { AgentLog::PROCESSING }
    extra_data { {} }
    agent_approved { false }

    trait :processing do
      state { AgentLog::PROCESSING }
    end

    trait :waiting_for_approval do
      state { AgentLog::WAITING_FOR_APPROVAL }
    end

    trait :approved do
      state { AgentLog::APPROVED }
      approved_at { Time.current }
    end

    trait :rejected do
      state { AgentLog::REJECTED }
      rejected_at { Time.current }
    end

    trait :agent_approved do
      agent_approved { true }
    end

    trait :ink_clusterer do
      name { "InkClusterer" }
    end

    trait :spam_classifier do
      name { "SpamClassifier" }
    end

    trait :with_owner do
      association :owner, factory: :user
    end

    trait :with_extra_data do
      extra_data { { "action" => "test_action", "details" => "test details" } }
    end
  end
end
