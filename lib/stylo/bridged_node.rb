class Stylo::BridgedNode < Stylo::Node

  key :bridged_class_name, String
  key :bridged_id, Integer

  def bridged_item
    self.bridged_class_name.constantize.send(:find, self.bridged_id)
  end

  def container?
    false
  end

  def merge_into(another)
    raise Stylo::MergeUnsupported unless another.class == self.class
    self.class.perform_before_merge(self, another)

    # do work
    self.update_attributes(:bridged_id => another.bridged_id)
    self.class.perform_after_merge(self, another)
  end
end





