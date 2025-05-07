require "csv"

class SpamClassifier
  include Raix::ChatCompletion
  include Raix::FunctionDispatch
  include AgentTranscript

  def initialize(user)
    self.user = user
    transcript << { system: prompt }
  end

  def perform
    chat_completion(loop: true, openai: "gpt-4o-mini")
    agent_log.waiting_for_approval!
  end

  def spam?
    agent_log.extra_data["spam"]
  end

  def agent_log
    @agent_log ||= AgentLog.create!(name: self.class.name, transcript: [], owner: user)
  end

  function :classify_as_spam,
           explanation_of_action: {
             type: "string",
             description: "Reasoning for classifying this account as spam"
           } do |arguments|
    agent_log.update(
      extra_data: {
        spam: true,
        explanation_of_action: arguments[:explanation_of_action]
      }
    )
    stop_looping!
  end

  function :classify_as_normal,
           explanation_of_action: {
             type: "string",
             description: "Reasoning for classifying this account as normal"
           } do |arguments|
    agent_log.update(
      extra_data: {
        spam: false,
        explanation_of_action: arguments[:explanation_of_action]
      }
    )
    stop_looping!
  end

  private

  attr_accessor :user

  def prompt
    <<~MESSAGE
      Given the following spam accounts:
      #{spam_accounts}

      And the following normal accounts:
      #{normal_accounts}

      Classify the following account as spam or normal:
      #{unclassified_account}

      Call either of the two available functions to classify the account.
    MESSAGE
  end

  def spam_accounts
    formatted_as_csv(users.spammer.order(created_at: :desc).limit(50))
  end

  def normal_accounts
    formatted_as_csv(users.not_spam.where.not(blurb: "").shuffle.take(50))
  end

  def users
    User.where(review_blurb: false)
  end

  def unclassified_account
    formatted_as_csv([user])
  end

  def formatted_as_csv(users)
    CSV.generate do |csv|
      csv << ["email", "name", "blurb", "time zone"]
      users.each { |user| csv << [user.email, user.name, user.blurb, user.time_zone] }
    end
  end
end
