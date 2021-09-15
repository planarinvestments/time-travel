require "rails/generators/active_record"

class TimeTravelGenerator < ActiveRecord::Generators::Base
  desc "Create a migration to add history tracking fields to your model. "+
       "The only argument this generator takes is the model on which the history tracking needs to be applied"
  argument :attributes, type: :array, default: [], banner: "field:type field:type"

  def self.source_root
    @source_root ||= File.expand_path('../templates', __FILE__)
  end

  def generate_migration
    if (behavior == :invoke && model_exists?) 
      migration_template("time_travel_migration_existing.rb.erb",
                       "db/migrate/#{migration_file_name}",
                       migration_version: migration_version)
    else
      migration_template("time_travel_migration_new.rb.erb",
                       "db/migrate/#{migration_file_name}",
                       migration_version: migration_version)
    end
  end

  def model_exists?
    File.exist?(File.join(destination_root, model_path))
  end

  def model_path
    @model_path ||= File.join("app", "models", "#{file_path}.rb")
  end

  def migration_name
    "add_time_travel_to_#{name.underscore.pluralize}"
  end

  def migration_file_name
    "#{migration_name}.rb"
  end

  def migration_class_name
    migration_name.camelize
  end

  def migration_version
    if Rails.version.start_with? "5"
      "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end
  end
end
