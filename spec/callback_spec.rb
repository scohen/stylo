#require File.dirname(__FILE__) + '/spec_helper'
require "spec_helper"

describe Stylo::Node do
  it_is_configured_like "there is an ontology called onto"



  context "when callbacks are enabled" do


    context "before_merge" do
      class BeforeMerge < Stylo::Node; end

      before do
        @from = @to = nil
        BeforeMerge.before_merge do |from, to|
          @from = from
          @to = to
        end

        Onto.node_types :node => BeforeMerge
      end

      it "should call before merge" do
        f = Onto.add("Foo")
        t = Onto.add("Foo2")
        @from.should be_nil
        @to.should be_nil

        f.merge_into(t)
        @from.should == f
        @to.should == t
      end

    end
    context "after_merge"  do
      class AfterMerge < Stylo::Node; end
      before do
        @from = @to = nil
        AfterMerge.after_merge do |from, to|
          @from = from
          @to = to
        end
        Onto.node_types :node => AfterMerge

      end

      it "should call after_merge" do
        f = Onto.add('Foo')
        t = Onto.add("Foo2")

        f.merge_into(t)
        @from.should == f
        @to.should == t
      end

    end
  end
end