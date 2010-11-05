require File.dirname(__FILE__) + '/spec_helper'

class BridgedObject

end

describe Stylo do
  it_should_behave_like 'it is configured'

  before(:each) do
    @root = Stylo.root
    @bridge = BridgedObject.new
    BridgedObject.stub!(:find).with(1).and_return(@bridge)
  end

  it "should have a root document with metadata" do

    @root.should_not be_nil
    @root.should be_kind_of(Node)
    @root.node_type.should == 'Root'
    @root.child_count.should == 0
    @root.collection.count.should == 1
  end

  it "should allow you to add a category" do
    cat = Stylo.add('Category')
    cat.should_not be_nil
    cat.category.should == 'Category'
    cat.parents.should == [@root.id]
    cat.parent_id.should == @root.id
    Stylo.root.child_count.should == 0 #no bridges
  end


  it "should allow you to add a category with a parent that exists" do
    parent = Stylo.add('Parent')
    child = Stylo.add('Child', parent)
    child.parents.should == [@root.id, parent.id]
    child.parent_id.should == parent.id
  end

  it "should allow you to access the parent categories" do
    parent = Stylo.add('Parent')
    child = Stylo.add('Child', parent)
    child.parent_categories.should == [@root.reload, parent.reload]
    grandchild = Stylo.add('Grandkid', child)
    grandchild.parent_categories.should == [@root.reload, parent.reload, child.reload]
  end

  it "should allow you to search for a category" do
    Stylo.search('Child').should be_empty
    child = Stylo.add('Child', Stylo.add('Parent'))
    Stylo.search('Child').first.should == child
  end

  it "should allow you to search for a category with a partial name" do
    parent = Stylo.add('Parent')
    Stylo.search('Paren').first.should == parent
    Stylo.search('Pare').first.should == parent
    Stylo.search('Pa').should be_empty
  end


  it "should allow you to add a node to a category" do
    parent = Stylo.add('Parent')
    child1 = Stylo.add('child1', parent)
    child2 = Stylo.add('child2', parent)

    child1.parent.should == parent
    child2.parent.should == parent
  end

  it "should allow you to get the children of a node" do
    parent = Stylo.add('Parent')
    child1 = Stylo.add('Child1', parent)
    child2 = Stylo.add("Child2", parent)

    parent.children.collect { |x| x.id.to_s }.sort.should == [child2.reload, child1.reload].collect { |x| x.id.to_s }.sort
  end

  it "should allow two children with the same name but with different hierarchies" do
    parent = Stylo.add('Parent')
    child1 = Stylo.add('Child1', parent)
    child2 = Stylo.add('Child2', parent)
    gc1 = Stylo.add('Grand', child1)
    gc2 = Stylo.add('Grand', child2)

    Stylo.search('Grand').collect{|x| x.id.to_s}.sort.should == [gc1, gc2].collect{|x| x.id.to_s}.sort
  end

  it "should move all grandchildren up to children when their parent is deleted" do
    parent = Stylo.add('Parent')
    child =  Stylo.add('Child', parent)
    grandkid = Stylo.add('Grandkid', child)
    child.destroy
    grandkid = grandkid.reload
    grandkid.parent_id.should == parent.id
    grandkid.parent.should == parent
    grandkid.parents.should == [@root.id, parent.id]
  end

  it "should not let you delete the root category"

  it "should allow you to set a description for a category" do
    desc = 'this is my description'
    cat = Stylo.add('Category', @root, {:description => desc})
    cat.description.should == desc
    cat.reload.description.should == desc
  end

  it "should chop up its description into unique words" do
    desc = "unique description Unique   words"
    cat = Stylo.add('Category', @root, {:description => desc})
    cat.search_terms.should_not be_nil
    cat.search_terms.should == ['unique', 'description', 'words']
  end

  it "should allow you to search the description for a category" do
    cat = Stylo.add('Category', @root, {:description => 'uniqueness is valid'})
    cat2 = Stylo.add('Cat2', @root, {:description => 'Uniqueness is nice'})

    Stylo.search('uniqueness').collect { |x| x.id.to_s }.sort.should == [cat, cat2].collect { |x| x.id.to_s }.sort
  end

  it "should require all words searched for be present in the description" do
    cat = Stylo.add('Category',@root, :description => 'takes 4 minutes')
    cat2 = Stylo.add('Category',@root, :description => 'takes 5 minutes')
    results = Stylo.search('5 minutes')
    results.size.should == 1    
  end

  it "should ignore stop words in the description for a category"

end

#bridging
describe Stylo do
  it_should_behave_like 'it is configured'

  
  class Mapper
    attr_accessor :id, :name, :why
  end

  class StraightUp
    attr_accessor :id, :category, :description
  end

  before(:each) do
    Stylo.bridge StraightUp
    Stylo.bridge Mapper, :mappings => {:category => :name,
                                              :description => :why}
    @root = Stylo.root
    
    @mapper = Mapper.new
    @mapper.stub!(:id).and_return(1)
    @mapper.stub!(:name).and_return("Name")
    @mapper.stub!(:why).and_return("Because I love things")

    @straight_up = StraightUp.new
    @straight_up.stub!(:id).and_return(2)
    @straight_up.stub!(:category).and_return('Category')
    @straight_up.stub!(:description).and_return("Description")

    Mapper.stub!(:find).with(1).and_return(@mapper)
    StraightUp.stub!(:find).with(2).and_return(@straight_up)
  end

  it "should be able to store a bridged object" do
    Stylo.add_item(@straight_up)
    Node.count.should == 2 #root and the bridged one.
    items = Stylo.search(@straight_up.category)
    items.size.should == 1

    item = items.first
    item.should be_kind_of(BridgedNode)
    item.bridged_item.should == @straight_up
  end

  it "should be able to store a mapped bridged object" do
    Stylo.add_item(@mapper)
    items = Stylo.search(@mapper.name)
    items.size.should == 1
    item = items.first
    item.should be_kind_of(BridgedNode)
    item.bridged_item.should == @mapper
  end

  it "should update the child counts recursively when a bridged child is added" do
    @root.reload.child_count.should == 0
    parent = Stylo.add('Parent')
    child = Stylo.add('Child',parent)

    @root.reload.child_count.should == 0

    grandchild = Stylo.add_item(@mapper,child)
    @root.reload.child_count.should == 1
    parent.reload.child_count.should == 1
    child.reload.child_count.should == 1
    grandchild.reload.child_count.should == 0

  end

end

describe Stylo do
  it_should_behave_like 'it is configured'

  class MyNode < Node

  end

  class MyBridgedNode < BridgedNode

  end

  it "should allow you to set the node class" do
    Stylo.node_types :node => MyNode, :bridged => MyBridgedNode

    Stylo.node_class.should == MyNode
    Stylo.root.should be_kind_of(MyNode)
    Stylo.add("Category").should be_kind_of(MyNode)
  end
end