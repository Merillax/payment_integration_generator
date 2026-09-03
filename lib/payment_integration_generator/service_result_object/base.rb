class ResultObjectBase
  def initialize(message, status)
    @message = message
    @status = status
  end

  def success?
    raise NotImplementedError
  end

  def failure?
    raise NoMatchingPatternError
  end

  def message
    @message
  end

  def status
    @status
  end
end