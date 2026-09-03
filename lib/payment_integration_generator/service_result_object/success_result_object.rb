require_relative "./base"

class SuccessResultObject < ResultObjectBase
  def initialize(message, status)
    super(message, status)
    @success = true
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end