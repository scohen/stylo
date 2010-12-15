begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

class Onto < Stylo::Ontology;
end

class Class
  def it_is_configured_like(what)
    mod = what.gsub(' ', '_').camelize.constantize
    include(mod)
  end
end

module ThereIsAnOntologyCalledOnto
  def self.included(base)
    base.class_eval do
      before(:each) do
        Onto.configure('test' => {'uri' => 'mongodb://localhost/mongontology_test'})

        Onto.database.should_not be_nil
        Onto.database.name.should == 'mongontology_test'
        Onto.node_class.count.should == 1 # root
      end

      after(:each) do
        Onto.reset
      end
    end
  end
end

def mark(&block)
  puts "----- RELEVANT -----"
  yield
  puts "----- TNAVELER -----"
end

