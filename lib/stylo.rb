# Mongontology
require 'mongo'
require 'node'


module StyloMethods
  include Mongo

  def self.included(clazz)
    clazz.extend(ClassMethods)
    clazz.class_eval do
      include InstanceMethods
    end
  end

  module ClassMethods

    def parse_uri(env)
      return env if env['uri'].blank?
      uri = URI.parse(env['uri'])
      raise InvalidScheme.new('must be mongodb') unless uri.scheme == 'mongodb'

      {'host'     => uri.host,
       'port'     => uri.port,
       'database' => uri.path.gsub(/^\//, ''),
       'username' => uri.user,
       'password' => uri.password,
              }
    end

    def environment
      @@environment
    end

    def configure(env, options={})
      @@environment = parse_uri(env[RAILS_ENV])

      @@connection = Mongo::Connection.new(environment['host'], environment['port'], options)
      @@database = @@connection.db(environment['database'])

      database.authenticate(environment['username'], environment['password']) if environment['username'] && environment['password']

      nil
    end

    def node_types(* args)
      unless args.empty?
        opts = args.extract_options!
        @bridged_node_class = opts.delete(:bridged) || BridgedNode
        @node_class = opts.delete(:node) || Node
        set_up_nodes
        ensure_root_node
      end
    end

    def node_class
      self.node_types :node => Node, :bridged => BridgedNode if @node_class.nil?
      @node_class
    end

    def bridged_node_class
      self.node_types :node => Node, :bridged => BridgedNode if @bridged_node_class.nil?
      
      @bridged_node_class
    end

    def database
      @@database
    end

    def index(index_spec)
      collection.create_index(index_spec)
    end

    def ensure_root_node
      node_class.first_or_create(:node_type => 'Root')
    end

    def set_up_nodes
      node_class.set_database_name database.name
      bridged_node_class.set_database_name database.name
    end

    def reset
      node_class.delete_all
      bridged_node_class.delete_all
      set_up_nodes
    end

    def bridge(clazz, opts = {})
      @@bridges ||= {}
      @@bridges[clazz] = opts
    end

    def bridges
      @@bridges
    end

  end

  module InstanceMethods

    def database
      self.class.database
    end
  end
end

class Stylo
  include StyloMethods

  attr_accessor :collection


  def self.root
    self.ensure_root_node
  end


  def self.add(name, parent=self.root, attrs={})

    attrs[:category] = name
    attrs[:parent_id] = parent.id
    attrs[:node_type] = 'Category'

    cat = node_class.first_or_new(attrs)
    add_node(cat, parent)
    cat
  end

  def self.add_item(item, parent=self.root)

    opts = bridges[item.class]
    return if opts.nil? #you didn't tell us that we needed to bridge this object type

    mappings = opts[:mappings] || {}

    mappings[:bridged_id] = :id unless mappings[:bridged_id]
    attrs = {:bridged_class_name => item.class.name,
             :node_type => 'Bridge'}

    [:bridged_id, :category, :description].each do |key|
      method = mappings[key] || key
      attrs[key] = item.send(method)
    end

    item = bridged_node_class.first_or_new(attrs)
    add_node(item, parent)
  end

  def self.search(search)
    return [] unless search && search.size > 2
    results = node_class.where(:category => /^#{search}/).all
    results +=  node_class.where(:search_terms => {'$all' => search.downcase.split(' ')}).all
    results.compact
  end

  def self.remove_from_hierarchy(node)
    node.collection.update({'parents' => node.id},
                           {'$pull' => {'parents' => node.id}})
    node.collection.update({'parent_id' => node.id}, {'$set' => {'parent_id' => node.parent_id}})
  end


  private

  def self.add_node(node, parent)
    return nil unless node.new_record?

    node.parents =  parent.parents + [parent.id]
    if node.save
      if node.is_a?(bridged_node_class)
        node.parents.each do |pid|
          node.collection.update({'_id' => pid}, {'$inc' =>{'child_count', 1}})
        end
        #node.collection.update({'_id' => {'$in' => node.parents}}, {'$inc' => {'child_count', 1}})
      end
    end
    node
  end

end


