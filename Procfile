web: bundle exec puma
release: rake db:migrate db:seed
worker: RAILS_MAX_THREADS=5 bundle exec sidekiq
