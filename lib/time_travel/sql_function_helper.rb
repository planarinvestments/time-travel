module TimeTravel
  class SqlFunctionHelper
    def self.create(schema=nil)
      connection = ActiveRecord::Base.connection
      gem_root = File.expand_path('../../../', __FILE__)
      ActiveRecord::Base.transaction do
        result = connection.execute("SHOW search_path;")
        if schema && !result.first["search_path"].eql?(schema)
          connection.execute "SET search_path TO #{schema};"
        end
        connection.execute(IO.read(gem_root + "/sql/create_column_value.sql"))
        connection.execute(IO.read(gem_root + "/sql/get_json_attrs.sql"))
        connection.execute(IO.read(gem_root + "/sql/update_history.sql"))
        connection.execute(IO.read(gem_root + "/sql/update_bulk_history.sql"))
        connection.execute(IO.read(gem_root + "/sql/update_latest.sql"))
      end
    end
  end
end
