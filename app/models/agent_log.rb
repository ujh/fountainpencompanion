class AgentLog < ApplicationRecord
  belongs_to :owner, polymorphic: true
end
