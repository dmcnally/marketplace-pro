class Bucket < ApplicationRecord
  SYSTEM_BUCKET_NAME = "system"
  IDENTITY_NAME = "identity"
  RESERVED_NAMES = [ SYSTEM_BUCKET_NAME, IDENTITY_NAME ].freeze

  has_many :recordings, dependent: :restrict_with_exception
  has_many :events, dependent: :restrict_with_exception
  has_many :memberships, dependent: :destroy
  has_many :membership_invites, dependent: :destroy
  has_many :people, through: :memberships
  has_many :csv_imports, dependent: :destroy

  scope :content, -> { where.not(name: RESERVED_NAMES) }

  validates :name, presence: true, uniqueness: true
  validate :system_name_cannot_change, if: :will_save_change_to_name?

  def self.system_bucket
    find_by(name: SYSTEM_BUCKET_NAME)
  end

  def self.identity
    find_by(name: IDENTITY_NAME)
  end

  def system_bucket?
    name == SYSTEM_BUCKET_NAME
  end

  def identity?
    name == IDENTITY_NAME
  end

  def system?
    RESERVED_NAMES.include?(name)
  end

  def content?
    !system?
  end

  private

  def system_name_cannot_change
    return unless RESERVED_NAMES.include?(name_in_database) && name != name_in_database

    errors.add(:name, "can't be changed for the #{name_in_database} bucket")
  end
end
