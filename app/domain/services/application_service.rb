class Services::ApplicationService
  def process(*args)
    raise NotImplementedError
  end

  def self.process(*args)
    new.process(*args)
  end

  protected

  def log(level, &block)
    Rails.logger.tagged(self.class.name) { |logger| logger.public_send(level, &block) }
  end
end
