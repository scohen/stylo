require File.dirname(__FILE__) + '/spec_helper'

describe Stylo::Node do
  it_is_configured_like 'there is an ontology called onto'

  it 'should have a path' do
    parent = Onto.add('Parent')
    child  = Onto.add('Child', parent)
    gc     = Onto.add('Grandkid', child)

    gc.path.should == 'Parent / Child / Grandkid'
    child.path.should == 'Parent / Child'
    parent.path.should == 'Parent'
  end

  it "should keep a list of path names" do
    children = build_linear_hierarchy(3)
    child    = children.last
    child.path_names.should_not be_empty
    child.path_names.should == children.collect(& :category)
  end

  it "should be able to tell if it's a parent" do
    parent = Onto.add('Parent')
    child = Onto.add('Child',parent)

    parent.should be_parent_of(child)
  end

  it "should be able to tell if it's a child" do
    parent = Onto.add('Parent')
    child = Onto.add('Child',parent)

    child.should be_child_of(parent)
  end

  it "should update the path names if its hierarchy is changed" do
    children = build_linear_hierarchy(5)
    killed   = children.delete(children[2])

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

  it "should update node paths if you update a node's name" do
    hier       = build_linear_hierarchy(5)
    n          = hier[1]
    n.category = "New Name"
    n.save

    n.path.split(' / ').last.should == "New Name"
    hier[2..-1].each do |child|
      child.reload.path_names[1].should == 'New Name'
    end

  end

  it "should be able to search for a node after its category has been renamed" do
    children = build_linear_hierarchy(5)
    renamed  = children[3]

    Onto.search(renamed.category).first.should == renamed
    renamed.category = "Gobbledygook Stuff"
    renamed.save

    Onto.search('Gobbledygook').first.should == renamed
    Onto.search('Stuff').first.should == renamed

  end

  it "should be able to search for keywords after its description has changed" do
    children          = build_linear_hierarchy(5)
    child             = children[3]

    child.description = "Once there was a man. A wonderful man."
    child.save

    Onto.search('wonderful').first.should == child
  end


  context "when altering the ontology" do
    class Bridged < Stylo::BridgedNode;
      key :bridged_id, BSON::ObjectId
    end

    class OtherObject
      include MongoMapper::Document
      key :name, String
      key :description, String
    end


    before do
      Onto.node_types :bridged => Bridged
      Onto.bridge OtherObject, :mappings => {:category => :name}

      @grandparent = Onto.add("Grandpa")
      @parent      = Onto.add("Parent", @grandparent)
      @child       = Onto.add("Child", @parent)
      @child2      = Onto.add("Child2")
      @grandchild2 = Onto.add("Grandkid2", @child2)

    end

    context "when merging a node with children" do
      before do
        @child2.merge_into(@child)
        @grandchild2 = @grandchild2.reload
      end

      it "should update the child path" do
        @grandchild2.parents.should include(@child.id)
        @grandchild2.parents.should_not include(@child2.id)
      end

      it "should update the parent id" do
        @grandchild2.parent_id.should == @child.id
      end

      it "should delete the old child node" do
        Onto.node(@child2.id).should be_nil
      end

      it "should update the path names" do
        @grandchild2.path_names.should include('Child')
      end

      context "when merging nodes with children" do
        before do
          @grandparent2 = Onto.add('Grandparent')
          @parent2      = Onto.add('Parent', @grandparent2)
          @child2       = Onto.add("Child2", @parent2)
          3.times { Onto.add_item(OtherObject.new, @child) }
          5.times { Onto.add_item(OtherObject.new, @child2) }
          @parent2.reload.child_count.should == 5
          @child.reload.child_count.should == 3
          @child2.reload.child_count.should == 5
          @grandparent2.reload.child_count.should == 5
          @child2.merge_into(@child)
        end

        it "should update the child count" do
          @child.reload.child_count.should == 8
          @grandparent.reload.child_count.should == 8
          @parent.reload.child_count.should == 8
          @parent2.reload.child_count.should == 0
          @grandparent2.reload.child_count.should == 0
        end

      end
    end

    context "when merging a parent into its child" do
      before do
        @child_child         = Onto.add("Second child", @child)
        @other_sibling       = Onto.add("Sib", @parent)
        @yet_another_sibling = Onto.add("Another sib", @parent)
        @parent.merge_into(@child)
      end

      it "should destroy the parent" do
        Onto.node(@parent.id).should be_nil
      end

      it "should update the original child's path" do
        @child.reload.parents.should_not be_include(@parent.id)
      end


      it "should update the parent id in the child" do

        @child.reload.parent_id.should == @grandparent.id

      end

      it "should update any sibling's parent ids" do
        @other_sibling.reload.parent.should == @child
        @yet_another_sibling.reload.parent.should == @child
      end

      it "should eliminate the child from the paths" do
        @parent.merge_into(@child)

        @child_child.reload.parents.should_not be_include(@parent.id)
      end
    end

    context "when merging a child into its parent" do
      before do
        @child_child  = Onto.add("Second child", @child)
        @child_child2 = Onto.add('Sib1', @child)
        @child.merge_into(@parent)
      end

      it "should eliminate the child id from its children" do
        @child_child.reload.parents.should_not be_include(@child.id)
      end
      it "should destroy the child" do
        Onto.node(@child.id).should be_nil
      end

      it "should update the parent_id on all siblings" do
        @child_child.reload.parent_id.should == @parent.id
        @child_child2.reload.parent_id.should == @parent.id
      end
    end


    context "when merging a bridged node with another" do
      before do
        @bridged  = Onto.add_item(OtherObject.create(:name => 'B1'), @child)
        @bridged2 = Onto.add_item(OtherObject.create(:name => 'B2'), @child2)
      end

      it "should allowed" do
        lambda { @bridged.merge_into(@bridged2) }.should_not raise_error(Stylo::MergeUnsupported)
      end

      context "after the merge is complete" do
        before do
          @bridged2.merge_into(@bridged)
          @bridged2.reload
        end

        it "should update the bridged id" do
          @bridged2.bridged_id.should == @bridged.bridged_id
        end

        it "should leave the original node" do
          Onto.node(@bridged2.id).should_not be_nil
        end
      end

      context "after the merge" do
        before { @bridged.merge_into(@bridged2) }
        it "should update the bridged_id of the original node" do
          @bridged.bridged_id.should == @bridged2.bridged_id
        end
      end

    end

    it "should allow you to move a node"


    it "should not let you merge a bridged node with a node" do
      lambda { @child.merge_into(@bridged) }.should raise_error(Stylo::MergeUnsupported)
    end

  end

  def build_linear_hierarchy(kids, first_child = Onto.root)
    child = first_child
    (1..kids).collect { child = Onto.add("child #{rand(kids * 10)}", child) }
  end

end