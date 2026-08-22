require_relative "./base"

class FailureResultObject < ResultObjectBase
  def initialize(message, status = nil)
    super(message, status)
    @success = false
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end