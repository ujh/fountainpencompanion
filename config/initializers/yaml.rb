Rails.application.config.after_initialize do
  ActiveRecord.yaml_column_permitted_classes += [Time]
end
