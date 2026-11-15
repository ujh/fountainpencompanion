class ApplicationRecord < ActiveRecord::Base
  MAX_COMMENT_LENGTH = 20_000
  MAX_DETAIL_LENGTH = 1_000

  self.abstract_class = true
end
