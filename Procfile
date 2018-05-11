web: bundle exec puma -t 5:15 -p ${PORT:-3000} -e ${RACK_ENV:-development}
release: rake db:migrate db:seed
