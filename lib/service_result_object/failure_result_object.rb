require_relative "./base"

class FailureResultObject < ResultObjectBase
  def initialize(message = nil, status = nil, data: nil)
    super(message, status, data)
    @success = false
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end