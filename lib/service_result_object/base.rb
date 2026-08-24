class ResultObjectBase
  def initialize(message, status, data)
    @message = message
    @status = status
    @data = data
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

  def data
    @data
  end
end