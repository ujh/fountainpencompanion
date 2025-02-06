Rails.application.config.after_initialize { ActiveRecord.yaml_column_permitted_classes += [Time] }
