require "csv"

class SpamClassifier
  include RubyLlmAgent

  class ClassifyAsSpam < RubyLLM::Tool
    description "Classify the account as spam"

    param :explanation_of_action, desc: "Reasoning for classifying this account as spam"

    def initialize(user, agent_log)
      @user = user
      @agent_log = agent_log
    end

    def execute(explanation_of_action:)
      @user.update(spam: true, spam_reason: "auto-spam")
      @agent_log.update(extra_data: { spam: true, explanation_of_action: explanation_of_action })
      halt "classified as spam"
    end
  end

  class ClassifyAsNormal < RubyLLM::Tool
    description "Classify the account as normal"

    param :explanation_of_action, desc: "Reasoning for classifying this account as normal"

    def initialize(user, agent_log)
      @user = user
      @agent_log = agent_log
    end

    def execute(explanation_of_action:)
      @user.update(spam: false, spam_reason: "auto-not-spam")
      @agent_log.update(extra_data: { spam: false, explanation_of_action: explanation_of_action })
      halt "classified as normal"
    end
  end

  MODEL_ID = "gpt-4.1-mini"

  SYSTEM_DIRECTIVE = <<~TEXT
    You are a spam classifier. You will be given examples of spam and normal
    accounts, and then asked to classify a new account.

    Call either of the two available functions to classify the account.
  TEXT

  def initialize(user)
    @user = user
  end

  def perform
    ask!(user_prompt)
    agent_log.waiting_for_approval!
  end

  def agent_log = find_or_create_agent_log(user)

  private

  attr_reader :user

  def tools = [ClassifyAsSpam.new(user, agent_log), ClassifyAsNormal.new(user, agent_log)]

  def user_prompt
    <<~MESSAGE
      Given the following spam accounts:
      #{spam_accounts}

      And the following normal accounts:
      #{normal_accounts}

      Classify the following account as spam or normal:
      #{unclassified_account}
    MESSAGE
  end

  def spam_accounts
    formatted_as_csv(users.spammer.order(created_at: :desc).limit(50), prefix: "spam")
  end

  def normal_accounts
    formatted_as_csv(users.not_spam.where.not(blurb: "").shuffle.take(50), prefix: "normal")
  end

  def users
    User.where(review_blurb: false)
  end

  def unclassified_account
    formatted_as_csv([user], prefix: "subject")
  end

  # Examples are shipped to OpenAI and persisted into AgentLog.transcript on
  # every classification. The first column used to be the user's email,
  # which scattered every example user's address into every unrelated
  # subject's transcript. Replace it with an opaque per-prompt token so
  # the example rows carry no PII at all and the agent still has a stable
  # identifier per row.
  def formatted_as_csv(users, prefix:)
    CSV.generate do |csv|
      csv << ["id", "name", "blurb", "time zone"]
      users.each_with_index do |user, i|
        csv << ["#{prefix}_#{i + 1}", user.name, user.blurb, user.time_zone]
      end
    end
  end
end
