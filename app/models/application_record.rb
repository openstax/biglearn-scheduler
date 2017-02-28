class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  validates :uuid, presence: true, uniqueness: true
end
