require File.dirname(__FILE__) + '/spec_helper'

describe Stylo::Node do
  it_is_configured_like 'there is an ontology called onto'

  it 'should have a path' do
    parent = Onto.add('Parent')
    child = Onto.add('Child', parent)
    gc = Onto.add('Grandkid', child)

    gc.path.should == 'Parent / Child / Grandkid'
    child.path.should == 'Parent / Child'
    parent.path.should == 'Parent'
  end

  it "should keep a list of path names" do
    children = build_linear_hierarchy(3)
    child = children.last
    child.path_names.should_not be_empty
    child.path_names.should == children.collect(& :category)
  end

  it "should update the path names if its hierarchy is changed" do
    children = build_linear_hierarchy(5)
    killed = children.delete(children[2])

    killed.destroy

    Stylo::Node.find(killed.id).should be_nil
    child = Stylo::Node.find(children.last.id)
    child.path_names.size.should == 4
    child.path_names.should == children.collect(& :category)
  end

  it "should display the path (path method)" do
    children = build_linear_hierarchy(5)
    children.last.path.should == children.collect(& :category).join(' / ')
  end

  it "should allow you to move a node"

  def build_linear_hierarchy(kids, first_child = Onto.root)
    child = first_child
    (1..kids).collect { child = Onto.add("child #{rand(kids * 10)}", child) }
  end
end