module TimeTravel
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load 'tasks/create_postgres_function.rake'
    end
  end
end
