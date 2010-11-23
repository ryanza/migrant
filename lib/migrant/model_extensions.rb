module Migrant
  module ModelExtensions
    attr_accessor :schema
    def structure(&block)
      # Using instance_*evil* to get the neater DSL on the models.
      # So, my_field in the structure block actually calls Migrant::Schema.my_field
      
      if self.superclass == ActiveRecord::Base
        @schema ||= Schema.new
        @schema.add_associations(self.reflect_on_all_associations)
        @schema.define_structure(&block)
      else
        self.superclass.structure(&block) # For STI, cascade all fields onto the parent model
        @schema = InheritedSchema.new(self.superclass.schema)
      end
    end
    
    # Same as defining a structure block, but with no attributes besides
    # relationships (such as in a many-to-many)
    def no_structure
      structure {}
    end
    
    def mock(attributes={}, recursive=true)
      attribs = @schema.columns.reject { |column| column.is_a?(DataType::ForeignKey)}.collect { |name, data_type| [name, data_type.mock] }.flatten

      # Only recurse to one level, otherwise things get way too complicated
      if recursive
        attribs += self.reflect_on_all_associations(:belongs_to).collect do |association| 
                    begin
                      (association.klass.respond_to?(:mock))? [association.name, association.klass.mock({}, false)] : nil
                    rescue NameError; nil; end # User hasn't defined association, just skip it
                   end.compact.flatten
      end
      new Hash[*attribs].merge(attributes)
    end
  end
end
