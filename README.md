[![codecov](https://codecov.io/gh/ujh/fountainpencompanion/branch/master/graph/badge.svg?token=A4PS79JPB3)](https://codecov.io/gh/ujh/fountainpencompanion)

# Goals

There's two things that FPC wants to do. First of all it should be a place where users can manage their inks & pens.

Secondly, we also want to take advantage of having the data of all users in one place and aggregate it somehow to provide additional value to the whole user base. For now that's just a simple list of brands and inks but that's of course only the beginning.

It is important to keep in mind that these two goals are in conflict at times. Allowing users to manage their collection of inks to me means that we don't change the user's data. So if one user wants to call the ink "Callifolio Andrinople" and the next one wants to call it "L'Artisan Pastellier Callifolio Andrinople" they should be free to do so. On the other hand, for clustering entries that refer to the same ink it would be nice if everyone named the inks the same. There are cases where I'm OK with changing entries (like spelling mistakes) but in general that should be kept to a minimum. Instead the system should be enhanced to have the ability to deal with these issues.

# Technology

Most parts of the app are written in Ruby on Rails. The inks part is written using React with a JSON API (the spec) backend.

# The current state

Both the Ruby and the React code aren't in the best of shape. I was in a rush to get everything released so less tests (if any) were written and the code is also not well designed. I want to change that in the future of course and I will keep an eye on these things from now on. Any additions shouldn't be modelled after how the rest of the code is done. They should be well structured and thoroughly covered by tests.

# How to contribute

I've collected a lot of issues. Most of them are not yet concretely thought out, so please reach out to me before starting to implement anything. Then we can discuss what makes sense and what doesn't. Feel free to also create issues for things that would would like to see get done.

## Local development

This app currently _does not_ have a Docker setup, but is meant to be used for "bare bones" development.

### Prerequisites

- PostgreSQL 14 installed locally (we need a database configured with `trust` for tests).
- Redis 6 installed locally or running in a container.

A convenience `docker-compose` file is available for Redis. Run with `docker-compose up`.

**Environment variables**

- See `.env` for relevant Redis variables.

Other prerequesites include:

- [rbenv](https://github.com/rbenv/rbenv) to manage Ruby version and virtual environment.
- [nvm](https://github.com/nvm-sh/nvm) to manage Node version and virtual environment.
- Yarn Classic installed in the Node environment (`npm install -g yarn`).
- Bundle installed in the Ruby environment (`gem install bundle`).
- (Optional) [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)

### Install dependencies

- Run `bundle install` to install Ruby dependencies.
- Run `yarn` to install Node dependencies.

### Create database

- `./bin/rails db:create`
- `./bin/rails db:environment:set RAILS_ENV=development`
- `./bin/rails db:reset`

### Running

Once you've set up everything you can run the whole thing with:

1. `bundle exec puma` in one terminal.
2. `bundle exec sidekiq` in another terminal.
3. `./bin/webpack-dev-server` in another terminal to speed up the JavaScript recompilation process during development.

This is assuming both PostgreSQL and Redis is running.

### Default database seed

By default a user and an admin will be generated (see `db/seeds.rb` for the username), with a random password. Since emails are mocked locally you can use the password reset and resend confirmation features for both the [user-](http://localhost:3000/users/sign_in) and [admin signin](http://localhost:3000/admins/sign_in) to get access to this account on localhost.

To test as a regular user, sign up as you would in production. Create at minimum two regular users to test some of the community features.

**Adding new inks for the first time**
A fresh database means the first time a regular user inputs a new ink brand or type, a cluster has to be made on the admin side. A mock email will pop up. Sign in as an admin and navigate to Macro clusters -> Clustering app. Create the new cluster(s). When getting started it might be useful to be logged in as an admin in one browser, and a regular user in another.

### Run tests

- Use `rake` (without any arguments) to run the rspec tests.
- Use `yarn jest` to run the front-end tests.

# Licensing

The code base is licensed under the MIT license.
