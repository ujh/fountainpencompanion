class CurrentlyInked < ApplicationRecord

  belongs_to :collected_ink
  belongs_to :collected_pen
  belongs_to :user

  delegate :name, to: :collected_ink, prefix: 'ink'
  delegate :name, to: :collected_pen, prefix: 'pen'

end
