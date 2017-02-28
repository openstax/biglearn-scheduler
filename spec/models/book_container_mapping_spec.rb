require 'rails_helper'

RSpec.describe BookContainerMapping, type: :model do
  subject { FactoryGirl.create :book_container_mapping }

  it { is_expected.to validate_presence_of :uuid                     }
  it { is_expected.to validate_presence_of :from_ecosystem_uuid      }
  it { is_expected.to validate_presence_of :to_ecosystem_uuid        }
  it { is_expected.to validate_presence_of :from_book_container_uuid }
  it { is_expected.to validate_presence_of :to_book_container_uuid   }

  it do
    is_expected.to(
      validate_uniqueness_of(:from_book_container_uuid)
        .scoped_to(:from_ecosystem_uuid, :to_ecosystem_uuid)
        .case_insensitive
    )
  end
end
