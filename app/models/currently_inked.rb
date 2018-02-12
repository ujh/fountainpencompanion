class CurrentlyInked < ApplicationRecord

  belongs_to :collected_ink
  belongs_to :collected_pen
  belongs_to :user

  delegate :name, to: :collected_ink, prefix: 'ink', allow_nil: true
  delegate :name, to: :collected_pen, prefix: 'pen', allow_nil: true

end
