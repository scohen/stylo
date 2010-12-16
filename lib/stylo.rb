require 'mongo'
require 'mongo_mapper'

module Stylo
  include Mongo
  autoload :Node, File.join(File.dirname(__FILE__), %w{    stylo node.rb    })
  autoload :Node, File.join(File.dirname(__FILE__), %w{    stylo bridged_node.rb    })

  module StyloMethods


    def self.included(clazz)
      clazz.extend(ClassMethods)

      clazz.instance_eval do
        class << self
          attr_accessor :environment,
                        :database,
                        :connection,
                        :collection,
                        :bridges,
                        :node_class,
                        :bridged_node_class
        end
      end

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

      def configure(env, options={})
        self.environment = parse_uri(env[::Rails.env])
        self.connection = Mongo::Connection.new(environment['host'], environment['port'], options)
        self.database = connection.db(environment['database'])
        self.collection = self.database.collection((env[::Rails.env]['collection'] || 'stylo.nodes'))
        self.database.authenticate(environment['username'], environment['password']) if environment['username'] && environment['password']
        self.node_types :node => Stylo::Node, :bridged => Stylo::BridgedNode
        nil
      end

      def node_types(* args)

        unless args.empty?
          opts = args.extract_options!
          self.bridged_node_class = opts.delete(:bridged) || Stylo::BridgedNode
          self.node_class = opts.delete(:node) || Stylo::Node
          self.set_up_nodes
          self.ensure_root_node
        end
      end

      def index(index_spec)
        self.collection.create_index(index_spec)
      end

      def ensure_root_node
        self.node_class.first_or_create(:node_type => 'Root')
      end

      def set_up_nodes

        self.node_class = Stylo::Node if node_class.nil?
        self.bridged_node_class = Stylo::BridgedNode if bridged_node_class.nil?
        self.node_class.set_database_name database.name
        self.node_class.set_collection_name collection.name
        self.node_class.stylo_class = self

        self.bridged_node_class.set_database_name database.name
        self.bridged_node_class.set_collection_name collection.name
        self.bridged_node_class.stylo_class = self

      end

      def reset
        self.node_class.delete_all
        self.bridged_node_class.delete_all
        set_up_nodes
      end

      def bridge(clazz, opts = {})
        self.bridges ||= {}
        self.bridges[clazz] = opts
      end

    end

    module InstanceMethods

      def database
        self.class.database
      end
    end
  end

  class MergeUnsupported < Exception; end

  class Ontology

    include Mongo

    def self.inherited(subclass)
      subclass.class_eval do
        include StyloMethods
      end
    end

    def self.root
      self.ensure_root_node
    end

    def self.node(id)
      Stylo::Node.find(id)
    end

    def self.bridged_nodes_for(bridged_object)
      id = bridged_object.send(:id)
      self.bridged_node_class.where(:bridged_id => id).all
    end

    def self.count
      Stylo::Node.count
    end

    def self.add(name, parent=self.root, attrs={})

      attrs[:category] = name
      attrs[:parent_id] = parent.id
      attrs[:node_type] = 'Category'

      cat = self.node_class.first_or_new(attrs)
      add_node(cat, parent)
      cat
    end

    def self.add_item(item, parent=self.root)
      opts = bridges[item.class]
      return if opts.nil? #you didn't tell us that we needed to bridge this object type

      mappings = opts[:mappings] || {}

      mappings[:bridged_id] = :id unless mappings[:bridged_id]
      attrs = {:bridged_class_name => item.class.name,
               :parent_id => parent.id,
               :node_type => 'Bridge'}

      [:bridged_id, :category, :description].each do |key|
        method = mappings[key] || key
        attrs[key] = item.send(method)
      end

      item = self.bridged_node_class.first_or_new(attrs)
      add_node(item, parent)
      item
    end

    def self.search(search, * args)
      return [] unless search && search.size > 2
      opts = args.extract_options!
      params = [{:category => /\b#{search}/i}, {:search_terms => {'$all' => search.downcase.split(' ')}}]

      query = Stylo::Node.where('$or' => params)
      if limit = opts.delete(:limit)
        query = query.limit(limit)
      end
      query.all.compact
    end

    def self.remove_from_hierarchy(node)
      #sequence is important here. First we remove our name from the path names of our children
      node.class.collection.update({'parents' => node.id},
                                   {'$pull' => {'path_names' => node.category}},:multi => true)

      # then we remove our ID from our children's parents array. If we executed this before
      # the above update, we wouldn't be able to find the correct path names
      node.class.collection.update({'parents' => node.id},
                                   {'$pull' => {'parents' => node.id}},:multi => true)

      node.class.collection.update({'parent_id' => node.id}, {'$set' => {'parent_id' => node.parent_id}},:multi => true)
    end


    private

    def self.add_node(node, parent_node_or_id)
      return nil unless node.new_record?
      parent = parent_node_or_id.is_a?(Stylo::Node)? parent_node_or_id : self.node(parent_node_or_id)
      node.parent_id = parent.id
      node.parents =  parent.parents + [parent.id]
      if node.save
        if node.is_a?(self.bridged_node_class)
          node.collection.update({:_id => {'$in' => node.parents}},{'$inc' => {'child_count'=> 1}},:multi => true)
        end
      end
      node
    end

  end

end


