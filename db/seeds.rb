# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# System Bucket (created first so it receives id 1 on a fresh database)
system_bucket = Bucket.find_or_create_by!(name: Bucket::SYSTEM_BUCKET_NAME)
identity_bucket = Bucket.find_or_create_by!(name: Bucket::IDENTITY_NAME)

# Default Bucket (recordings and events depend on it)
bucket = Bucket.find_or_create_by!(name: "Default")
Current.bucket = bucket

# Second content bucket for local multi-bucket workflows
second_bucket = Bucket.find_or_create_by!(name: "Second")

# Default Person
person_card = PersonCard.find_or_create_by!(first_name: "David", last_name: "McNally")
recording = identity_bucket.recordings.find_or_create_by!(recordable: person_card)
person = Person.find_or_create_by!(recording: recording)

# Default User
user = User.find_or_initialize_by(email_address: "sysadmin@example.com")
if user.new_record?
  user.password = "testing"
end
user.person = person
user.save!

[
  [ system_bucket, :admin ],
  [ bucket, :admin ]
].each do |membership_bucket, role|
  membership = Membership.find_or_initialize_by(person:, bucket: membership_bucket)
  membership.role = role
  membership.save!
end

# Non-sys-admin Default Bucket Admin
default_admin_card = PersonCard.find_or_create_by!(first_name: "Default", last_name: "Admin")
default_admin_recording = identity_bucket.recordings.find_or_create_by!(recordable: default_admin_card)
default_admin = Person.find_or_create_by!(recording: default_admin_recording)

default_admin_user = User.find_or_initialize_by(email_address: "admin@example.com")
if default_admin_user.new_record?
  default_admin_user.password = "testing"
end
default_admin_user.person = default_admin
default_admin_user.save!

[
  bucket,
  second_bucket
].each do |admin_bucket|
  default_admin_membership = Membership.find_or_initialize_by(person: default_admin, bucket: admin_bucket)
  default_admin_membership.role = :admin
  default_admin_membership.save!
end

Membership.find_by(person: default_admin, bucket: system_bucket)&.destroy!
