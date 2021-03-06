module Rabl
  class Builder
    include Rabl::Partials

    # Constructs a new rabl hash based on given object and options
    # options = { :format => "json", :root => true, :child_root => true,
    #   :attributes, :node, :child, :glue, :extends }
    #
    def initialize(options={}, &block)
      @options    = options
      @_scope     = options[:scope]
    end

    # Given an object and options, returns the hash representation
    # build(@user, :format => "json", :attributes => { ... }, :root_name => "user")
    def build(object, options={})
      @_object = object
      compile_hash(options)
    end

    protected

    # Returns a hash representation of the data object
    # compile_hash(:root_name => false)
    # compile_hash(:root_name => "user")
    def compile_hash(options={})
      @_result = {}
      # Extends
      @options[:extends].each do |settings|
        extends(settings[:file], settings[:options], &settings[:block])
      end if @options.has_key?(:extends)
      # Attributes
      @options[:attributes].each_pair do |attribute, name|
        attribute(attribute, :as => name)
      end if @options.has_key?(:attributes)
      # Node
      @options[:node].each do |settings|
        node(settings[:name], settings[:options], &settings[:block])
      end if @options.has_key?(:node)
      # Children
      @options[:child].each do |settings|
        child(settings[:data], settings[:options], &settings[:block])
      end if @options.has_key?(:child)
      # Glues
      @options[:glue].each do |settings|
        glue(settings[:data], &settings[:block])
      end if @options.has_key?(:glue)

      # Wrap result in root
      if options[:root_name].present?
        @_root_name = options[:root_name].respond_to?(:call) ? options[:root_name].call(@_object) : options[:root_name]
      else # no root
        @_root_name = nil
      end

      # Return Results
      @_root_name ? { @_root_name => @_result } : @_result
    end

    # Indicates an attribute or method should be included in the json output
    # attribute :foo, :as => "bar"
    def attribute(name, options={})
      @_result[options[:as] || name] = @_object.send(name) if @_object && @_object.respond_to?(name)
    end
    alias_method :attributes, :attribute

    # Creates an arbitrary node that is included in the json output
    # node(:foo) { "bar" }
    # node(:foo) { "bar" }
    # node(:foo, :if => lambda { |m| m.foo.present? }) { "bar" }
    def node(name, options={}, &block)
      return unless resolve_condition(options)
      result = block.call(@_object)
      if name.present?
        @_result[name] = result
      elsif result.respond_to?(:each_pair) # merge hash into root hash
        @_result.merge!(result)
      end
    end
    alias_method :code, :node

    # Creates a child node that is included in json output
    # child(@user) { attribute :full_name }
    # child(@user => :person) { ... }
    # child(@users => :people) { ... }
    def child(data, options={}, &block)
      return false unless data.present? && resolve_condition(options)
      name, object = data_name(data), data_object(data)
      include_root = is_collection?(object) && @options[:child_root] # child @users
      engine_options = @options.slice(:child_root).merge(:root => include_root)
      object = { object => name } if data.respond_to?(:each_pair) && object # child :users => :people
      @_result[name] = self.object_to_hash(object, engine_options, &block)
    end

    # Glues data from a child node to the json_output
    # glue(@user) { attribute :full_name => :user_full_name }
    def glue(data, &block)
      return false unless data.present?
      object = data_object(data)
      glued_attributes = self.object_to_hash(object, :root => false, &block)
      @_result.merge!(glued_attributes) if glued_attributes
    end

    # Extends an existing rabl template with additional attributes in the block
    # extends("users/show") { attribute :full_name }
    def extends(file, options={}, &block)
      options = @options.slice(:child_root).merge(options).merge(:object => @_object)
      result = self.partial(file, options, &block)
      @_result.merge!(result) if result
    end

    protected

    # resolve_condition(:if => true) => true
    # resolve_condition(:if => lambda { |m| false }) => false
    # resolve_condition(:unless => lambda { |m| true }) => true
    def resolve_condition(options)
      return true if options[:if].nil? && options[:unless].nil?
      result = options[:if] == true || (options[:if].respond_to?(:call) && options[:if].call(@_object)) if options.has_key?(:if)
      result = options[:unless] == false || (options[:unless].respond_to?(:call) && !options[:unless].call(@_object)) if options.has_key?(:unless)
      result
    end
  end
end
