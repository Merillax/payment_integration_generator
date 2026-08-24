require_relative "./base"

class SuccessResultObject < ResultObjectBase
  def initialize(message = nil, status = nil, data: nil)
    super(message, status, data)
    @success = true
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end