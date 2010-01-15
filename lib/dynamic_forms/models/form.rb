# Developed by Chris Powers, Killswitch Collective on 09/10/2008
#
# The Form holds information about a dynamic form that the 
# client can build and users can fill out and submit.
module DynamicForms
  module Models
    module Form
      
      def self.included(model)
        model.extend(ClassMethods)
        model.send(:include, InstanceMethods)
        model.send(:include, Validations)
        model.send(:include, NamedScopes)
        model.send(:include, Relationships)
        
        model.class_eval do
          ::FormField::TYPES.each do |field_type|
            # create has_many for each field type
            has_many field_type.pluralize.to_sym, 
                     :class_name => "::FormField::#{field_type.camelize}"
            
            # create setter to receive form data for these type of fields
            define_method "#{field_type}=" do |fields|
              removed_fields = send(field_type.pluralize.to_sym).dup
              fields.each_pair do |key, hash|
                if hash[:id] && !new_record?
                  removed_fields.delete_if {|f| f.id == hash[:id].to_i}
                  item = send(field_type.pluralize.to_sym).find(hash[:id])
                  item.update_attributes(hash)
                else
                  send(field_type.pluralize.to_sym).build(hash)
                end
              end
              send(field_type.pluralize.to_sym).delete(*removed_fields)
            end
          end
          
          alias_method_chain :form_fields, :pre_save_accessibility
        end
      end
      
      module Validations
        def self.included(model)
          model.class_eval do
            validates_presence_of :name
          end
        end
      end
      
      module NamedScopes
        def self.included(model)
          model.class_eval do
            named_scope :active, :conditions => ["active = ?", true]
          end
        end
      end
      
      module Relationships
        def self.included(model)
          model.class_eval do
            belongs_to :formable, :polymorphic => true
            
            has_many :form_fields, 
                     :order => 'position ASC', 
                     :dependent => :destroy, 
                     :class_name => "::FormField"
            
            has_many :form_submissions, 
                     :order => 'created_at DESC', 
                      :class_name => "::FormSubmission", 
                     :dependent => :destroy do  
              # Takes the pain out of creating a form submission object!
              # @submission = form.form_submissions.submit(params[:form_submission])
              # --
              # Author:: Jacob Basham, Killswitch Collective 12-19-2008
              # ++
              def submit(attributes, throw_error = false)
                submission = proxy_owner.form_submissions.build
                attributes.each_pair do |method_name, value|
                  submission.send("#{method_name}=".to_sym, value)
                end
                submission.send(throw_error ? :save! : :save)
                return submission
              end
              
              # Just like #submit, but raises an error
              # --
              # Author:: Jacob Basham, Killswitch Collective 12-19.2008
              # ++
              def submit!(attributes)
                return self.submit(attributes, true)
              end
              
            end
          end
        end
      end
      
      module InstanceMethods
        # the form_fields association doesn't always load on build, 
        # so here's a fix...
        def form_fields_with_pre_save_accessibility
          orig = self.form_fields_without_pre_save_accessibility
          if orig.blank?
            method_names = ::FormField::TYPES.collect { |t| t.pluralize.to_sym }
            arr = method_names.inject([]) { |arr, method_name| 
              arr.concat self.send(method_name) }
            arr.sort { |a,b| a.position <=> b.position }
          else
            orig
          end
        end
        
        def field_keys
          self.form_fields.map(&:name)
        end
      end
      
      module ClassMethods
        
      end
      
    end
  end
end
