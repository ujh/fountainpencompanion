module Bots
  class SpamClassifier < Bots::Base
    def initialize(user)
      self.user = user
    end

    def run
      spam?
    end

    private

    def spam?
      response_message.include?("spam") and !response_message.include?("normal")
    end

    def prompt
      <<~MESSAGE
        Given the following spam accounts:
        #{spam_accounts}

        And the following normal accounts:
        #{normal_accounts}

        Classify the following account as spam or normal:
        #{unclassified_account}

        Return only "spam" if spam account and "normal" if normal account.
      MESSAGE
    end

    attr_accessor :user

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
end
