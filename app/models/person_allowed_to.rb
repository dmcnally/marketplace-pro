class PersonAllowedTo
  def initialize(person:, bucket:)
    @person = person
    @bucket = bucket
  end

  def allowed?(action, subject)
    raise ArgumentError, "action cannot be nil" if action.nil?
    raise ArgumentError, "subject cannot be nil" if subject.nil?

    policy = policy_for(subject)
    return false unless policy

    method_name = :"can_#{action}?"
    return false unless policy.respond_to?(method_name)

    if subject.is_a?(Class)
      policy.public_send(method_name)
    else
      policy.public_send(method_name, subject)
    end
  end

  private

  attr_reader :person, :bucket

  def policy_for(subject)
    policy_class = policy_class_for(subject)
    return unless policy_class

    policy_class.new(person:, bucket:)
  end

  def policy_class_for(subject)
    "#{subject_name_for(subject)}Policy".safe_constantize
  end

  def subject_name_for(subject)
    return subject.name if subject.is_a?(Class)

    subject.model_name.name
  end
end
