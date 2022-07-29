web: bundle exec puma
release: rake db:migrate db:seed
worker: trap '' SIGTERM; bundle exec sidekiq -c 5 -q default -q mailers & bundle exec sidekiq -c 1 -q reviews & wait -n; kill -SIGTERM -$$; wait
