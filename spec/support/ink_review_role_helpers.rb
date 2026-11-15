require "pg"

module InkReviewRoleHelpers
  SKILL_DIR = Rails.root.join(".claude/skills/review-ignored-inks")

  def self.included(base)
    base.after do
      if IgnoredInksReview.instance_variable_get(:@connection)
        IgnoredInksReview.connection.close
        IgnoredInksReview.instance_variable_set(:@connection, nil)
      end
      ink_review_roles.each do |role|
        admin_connection.exec("DROP OWNED BY #{role}")
        admin_connection.exec("DROP ROLE #{role}")
      end
      admin_connection.close if @admin_connection
    end
  end

  def ink_review_roles
    @ink_review_roles ||= []
  end

  # A connection outside the transaction RSpec wraps each example in, so roles
  # and grants are committed and visible to the role's own connection.
  def admin_connection
    @admin_connection ||= PG.connect(**test_database_params)
  end

  def test_database_params
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    {
      host: config[:host],
      port: config[:port],
      dbname: config[:database],
      user: config[:username],
      password: config[:password]
    }.compact
  end

  # Creates a login role with the grants of references/database-role.sql plus
  # any extra statements (with %{role} for the role name) and returns its
  # connection string.
  def create_ink_review_role(*extra_statements)
    role = "fpc_ink_review_test_#{SecureRandom.hex(4)}"
    password = SecureRandom.hex(16)
    admin_connection.exec("CREATE ROLE #{role} LOGIN PASSWORD '#{password}'")
    ink_review_roles << role
    database = test_database_params.fetch(:dbname)
    admin_connection.exec(
      SKILL_DIR
        .join("references/database-role.sql")
        .read
        .gsub(/\bfpc_ink_review\b/, role)
        .gsub(/\bdefaultdb\b/, PG::Connection.quote_ident(database))
    )
    extra_statements.each { |statement| admin_connection.exec(format(statement, role:)) }
    test_database_params
      .merge(user: role, password:)
      .map { |key, value| "#{key}=#{value}" }
      .join(" ")
  end

  def with_ink_review_url(url)
    previous = ENV["FPC_INK_REVIEW_DATABASE_URL"]
    ENV["FPC_INK_REVIEW_DATABASE_URL"] = url
    yield
  ensure
    ENV["FPC_INK_REVIEW_DATABASE_URL"] = previous
  end
end
