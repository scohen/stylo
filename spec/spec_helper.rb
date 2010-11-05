begin
  require File.dirname(__FILE__) + '/../../../../spec/spec_helper'
rescue LoadError
  puts "You need to install rspec in your base app"
  exit
end

plugin_spec_dir = File.dirname(__FILE__)
ActiveRecord::Base.logger = Logger.new(plugin_spec_dir + "/debug.log")

describe 'it is configured', :shared => true do
  before(:each) do
    Stylo.configure('test' => {'uri' => 'mongodb://localhost/mongontology_test'})
    
    Stylo.database.should_not be_nil
    Stylo.database.name.should == 'mongontology_test'

    Node.count.should == 1 # root
  end

  after(:each) do
    Stylo.reset
  end

end
