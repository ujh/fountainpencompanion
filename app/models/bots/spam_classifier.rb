module Bots
  class SpamClassifier < Bots::Base
    def initialize(user)
      self.user = user
    end

    def run
    end

    private

    attr_accessor :user
  end
end
