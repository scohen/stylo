require File.dirname(__FILE__) + '/spec_helper'


describe Stylo do
  class Onto1 < Stylo::Ontology;
  end
  class Onto2 < Stylo::Ontology;
  end

  class Node1 < Stylo::Node;
  end
  class BridgedNode1 < Stylo::BridgedNode;
  end
  class Node2 < Stylo::Node;
  end
  class BridgedNode2 < Stylo::BridgedNode;
  end

  it "should allow you to configure separate classes' databases differently" do
    Onto1.configure 'test' => {'uri' => 'mongodb://localhost/onto1'}
    Onto2.configure 'test' => {'uri' => 'mongodb://localhost/onto2'}


    Onto1.database.name.should == 'onto1'
    Onto2.database.name.should == 'onto2'
  end

  it "should allow you to set the collection" do
    Onto1.configure 'test' => {'uri'        => 'mongodb://localhost/onto1',
                               'collection' => 'my_collection'}
    Stylo::Node.collection.name.should == 'my_collection'
  end


  context "when setting node classes" do
    before do
      Onto1.configure 'test' => {'uri' => 'mongodb://localhost/onto1', 'collection' => 'my_collection'}
      Onto1.node_types :node => Node1, :bridged => BridgedNode1
    end

    it "should allow you to set the collection on classes you specify" do
      Stylo::Node.collection.name.should == 'my_collection'
      Onto1.node_class.collection.name.should == 'my_collection'
      Onto1.bridged_node_class.collection.name.should == 'my_collection'
      Onto1.bridged_node_class.should_not == Onto1.node_class
    end

    context "and there are two ontologies" do
      before do
        Onto2.configure 'test' => {'uri'        => 'mongodb://localhost/onto2',
                                   'collection' => 'onto2'
        }
        Onto2.node_types :node => Node2, :bridged => BridgedNode2
      end

      it 'should allow you to configure separate node classes' do
        Onto1.node_class.should == Node1
        Onto1.bridged_node_class.should == BridgedNode1

        Onto2.node_class.should == Node2
        Onto2.bridged_node_class.should == BridgedNode2
      end

      it "should allow you to set different collection names for different ontologies" do
        Onto1.collection.name.should == "my_collection"
        Onto2.collection.name.should == 'onto2'
      end
    end
  end
end


describe Onto do
  class BridgedObject;
  end

  it_is_configured_like 'there is an ontology called onto'

  before(:each) do
    @root   = Onto.root
    @bridge = BridgedObject.new
    BridgedObject.stub!(:find).with(1).and_return(@bridge)
  end

  it "should have a root document with metadata" do

    @root.should_not be_nil
    @root.should be_kind_of(Stylo::Node)
    @root.node_type.should == 'Root'
    @root.child_count.should == 0
    @root.collection.count.should == 1
  end

  it "should allow you to add a category" do
    cat = Onto.add('Category')
    cat.should_not be_nil
    cat.category.should == 'Category'
    cat.parents.should == [@root.id]
    cat.parent_id.should == @root.id
    Onto.root.child_count.should == 0 #no bridges
  end

  it "should allow you to add a category with a parent that exists" do
    parent = Onto.add('Parent')
    child  = Onto.add('Child', parent)
    child.parents.should == [@root.id, parent.id]
    child.parent_id.should == parent.id
  end

  it "should allow you to access the parent categories" do
    parent = Onto.add('Parent')
    child  = Onto.add('Child', parent)
    child.parent_categories.should == [@root.reload, parent.reload]
    grandchild = Onto.add('Grandkid', child)
    grandchild.parent_categories.should == [@root.reload, parent.reload, child.reload]
  end

  it "should allow you to add a node to a category" do
    parent = Onto.add('Parent')
    child1 = Onto.add('child1', parent)
    child2 = Onto.add('child2', parent)

    child1.parent.should == parent
    child2.parent.should == parent
  end

  it "should allow you to get the children of a node" do
    parent = Onto.add('Parent')
    child1 = Onto.add('Child1', parent)
    child2 = Onto.add("Child2", parent)

    parent.children.collect { |x| x.id.to_s }.sort.should == [child2.reload, child1.reload].collect { |x| x.id.to_s }.sort
  end

  it "should allow two children with the same name but with different hierarchies" do
    parent = Onto.add('Parent')
    child1 = Onto.add('Child1', parent)
    child2 = Onto.add('Child2', parent)
    gc1    = Onto.add('Grand', child1)
    gc2    = Onto.add('Grand', child2)

    Onto.search('Grand').collect { |x| x.id.to_s }.sort.should == [gc1, gc2].collect { |x| x.id.to_s }.sort
  end

  it "should move all grandchildren up to children when their parent is deleted" do
    parent   = Onto.add('Parent')
    child    = Onto.add('Child', parent)
    grandkid = Onto.add('Grandkid', child)
    child.destroy
    grandkid = grandkid.reload
    grandkid.parent_id.should == parent.id
    grandkid.parent.should == parent
    grandkid.parents.should == [@root.id, parent.id]
  end

  it "should not let you delete the root category"

  it "should allow you to set a description for a category" do
    desc = 'this is my description'
    cat  = Onto.add('Category', @root, {:description => desc})
    cat.description.should == desc
    cat.reload.description.should == desc
  end

  it "should chop up its description into unique words" do
    desc = "unique description Unique   words"
    cat  = Onto.add('Category', @root, {:description => desc})
    cat.search_terms.should_not be_nil
    cat.search_terms.should == ['unique', 'description', 'words']
  end

  it "should allow you to search the description for a category" do
    cat  = Onto.add('Category', @root, {:description => 'uniqueness is valid'})
    cat2 = Onto.add('Cat2', @root, {:description => 'Uniqueness is nice'})

    Onto.search('uniqueness').collect { |x| x.id.to_s }.sort.should == [cat, cat2].collect { |x| x.id.to_s }.sort
  end

  it "should require all words searched for be present in the description" do
    cat     = Onto.add('Category', @root, :description => 'takes 4 minutes')
    cat2    = Onto.add('Category', @root, :description => 'takes 5 minutes')
    results = Onto.search('5 minutes')
    results.size.should == 1
  end

  it "should ignore stop words in the description for a category"

end

#bridging"
describe Onto do
  it_is_configured_like 'there is an ontology called onto'


  class Mapper
    attr_accessor :id, :name, :why
  end

  class StraightUp
    attr_accessor :id, :category, :description
  end

  before(:each) do
    Onto.bridge StraightUp
    Onto.bridge Mapper, :mappings => {:category    => :name,
                                      :description => :why}
    @root        = Onto.root

    @mapper      = mapper_with_id_category_and_description(1, "Name", "Because I love things")


    @straight_up = StraightUp.new
    @straight_up.stub!(:id).and_return(2)
    @straight_up.stub!(:category).and_return('Category')
    @straight_up.stub!(:description).and_return("Description")

    Mapper.stub!(:find).with(1).and_return(@mapper)
    StraightUp.stub!(:find).with(2).and_return(@straight_up)
  end

  it "should be able to store a bridged object" do
    Stylo::BridgedNode.database.name.should == Stylo::Node.database.name
    Stylo::BridgedNode.collection.name.should == Stylo::Node.collection.name
    Onto.database.name.should == Stylo::BridgedNode.database.name
    Onto.add_item(@straight_up)
    Stylo::Node.count.should == 2 #root and the bridged one.
    items = Onto.search(@straight_up.category)
    items.size.should == 1

    item = items.first
    item.should be_kind_of(Stylo::BridgedNode)
    item.bridged_item.should == @straight_up
  end

  it "should be able to store a mapped bridged object" do
    Onto.add_item(@mapper)
    items = Onto.search(@mapper.name)
    items.size.should == 1
    item = items.first
    item.should be_kind_of(Stylo::BridgedNode)
    item.bridged_item.should == @mapper
  end

  it "should be able to find all bridged nodes belonging to a bridged object" do
    cat1 = Onto.add("New Category")
    cat2 = Onto.add("New Category2")

    cat1.should_not be_nil

    b1      = Onto.add_item(@mapper)
    b2      = Onto.add_item(@mapper, cat1)
    b3      = Onto.add_item(@mapper, cat2)

    bridged = Onto.bridged_nodes_for(@mapper)
    bridged.should_not be_empty
    bridged.should include(b1)
    bridged.should include(b2)
    bridged.should include(b3)
  end

  it "should allow you to add a bridged item to several different parts of the tree" do
    parent = Onto.root
    t1     = %w{first path down}.collect { |x| parent = Onto.add(x, parent) }
    parent = Onto.root
    t2     = %w{another path down}.collect { |x| parent = Onto.add(x, parent) }
    parent = Onto.root
    t3     = %w{yet another path}.collect { |x| parent = Onto.add(x, parent) }

    Onto.add_item(@mapper, t1.last)
    Onto.add_item(@mapper, t2.last)
    Onto.add_item(@mapper, t3.last)

    Onto.bridged_nodes_for(@mapper).size.should == 3
  end

  it "should update the child counts recursively when a bridged child is added" do
    @root.reload.child_count.should == 0
    parent = Onto.add('Parent')
    child  = Onto.add('Child', parent)

    @root.reload.child_count.should == 0

    grandchild = Onto.add_item(@mapper, child)
    @root.reload.child_count.should == 1
    parent.reload.child_count.should == 1
    child.reload.child_count.should == 1
    grandchild.reload.child_count.should == 0

  end

  it "should be able to give you the leaves of a node" do
    parent = Onto.add('Parent')
    subcat = Onto.add("Subcat", parent)
    # root category

    child1 = Onto.add_item(mapper_with_id_category_and_description(1, "Root Child", "child1"))
    # parent category
    child2 = Onto.add_item(mapper_with_id_category_and_description(2, "Parent Child", "child2"), parent)
    # child category
    child3 = Onto.add_item(mapper_with_id_category_and_description(3, "Subcat Child", "child3"), subcat)

    child1.should_not be_nil
    child2.should_not be_nil
    child3.should_not be_nil

    child3.parents.should == [Onto.root.id, parent.id, subcat.id]
    Onto.root.reload.child_count.should == 3
    parent.reload.child_count.should == 2
    subcat.reload.child_count.should == 1


    Onto.root.all_leaves.size.should == 3
    Onto.root.all_leaves.should == [child1.reload, child2.reload, child3.reload]
  end

  def mapper_with_id_category_and_description(id, category, description)
    mapper = Mapper.new
    mapper.stub!(:id).and_return(id)
    mapper.stub!(:name).and_return(category)
    mapper.stub!(:why).and_return(description)
    mapper
  end

end

describe Onto do
  it_is_configured_like 'there is an ontology called onto'

  class MyNode < Stylo::Node

  end

  class MyBridged < Stylo::BridgedNode

  end

  it "should allow you to set the node class" do
    Onto.node_types :node => MyNode, :bridged => MyBridged

    Onto.node_class.should == MyNode
    Onto.root.should be_kind_of(MyNode)
    Onto.add("Category").should be_kind_of(MyNode)
  end
end

#searching
describe Onto do
  it_is_configured_like 'there is an ontology called onto'

  before(:each) do
    @root   = Onto.root
    @bridge = BridgedObject.new
    BridgedObject.stub!(:find).with(1).and_return(@bridge)
  end


  it "should allow you to search for a category" do
    Onto.search('Child').should be_empty
    child = Onto.add('Child', Onto.add('Parent'))
    Onto.search('Child').first.should == child
  end

  it "should ignore case when searching for a category" do
    cat = Onto.add('ChIlD')
    Onto.search('child').first.should == cat
  end

  it "should allow you to search for every word in a category" do
    parent = Onto.add("Standard parent category")
    Onto.search('Standard').first.should == parent
    Onto.search('parent').first.should == parent
    Onto.search('category').first.should == parent
  end

  it "should allow you to search for a category with a partial name" do
    parent = Onto.add('Parent')
    Onto.search('Paren').first.should == parent
    Onto.search('Pare').first.should == parent
    Onto.search('Pa').should be_empty
  end

  it "should allow you to limit the results" do
    parents = (1..10).collect { Onto.add("Parent - #{rand}") }
    Onto.search("Parent", :limit => 3).size.should == 3
  end
end