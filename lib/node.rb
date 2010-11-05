require 'mongo_mapper'

class Node
  include MongoMapper::Document
  key :node_type, String
  key :category, String, :index => true
  key :description, String, :default => ''
  key :search_terms, Array, :index => true
  key :parents, Array, :index => true
  key :parent_id, BSON::ObjectId
  key :child_count, Integer, :default => 0

  timestamps!

  before_destroy :remove_from_hierarchy
  before_save :build_search_terms

  def parent_categories
    @parent_categories ||=  self.class.where('_id' => {'$in' => parents}).all
  end

  def parent
    @parent ||= self.class.find(self.parent_id)
  end

  def children
    self.class.where(:parent_id => id).all
  end

  def remove_from_hierarchy
    Stylo.remove_from_hierarchy(self)
  end

  def build_search_terms
    self.search_terms = self.description.downcase.split(' ').uniq if self.description
  end

end

