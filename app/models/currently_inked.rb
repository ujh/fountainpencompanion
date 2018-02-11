class CurrentlyInked < ApplicationRecord

  belongs_to :collected_ink
  belongs_to :collected_pen

  delegate :name, to: :collected_ink, prefix: true
  delegate :name, to: :collected_pen, prefix: true

end
