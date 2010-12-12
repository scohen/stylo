module Stylo
  module Callbacks

    def self.included(clazz)
      clazz.extend(ClassMethods)
      clazz.class_eval do
        include InstanceMethods
      end
    end

    module ClassMethods
      def before_merge(&block)
        @before_merge = block if block_given?
      end

      def perform_before_merge(from, to)
        if @before_merge
          @before_merge.call(from, to)
        end
      end

      def after_merge(&block)
        @after_merge = block if block_given?
      end

      def perform_after_merge(from, to)
        if @after_merge
          @after_merge.call(from, to)
        end
      end
    end

    module InstanceMethods

    end
  end
end