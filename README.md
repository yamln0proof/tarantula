# Tarantula
A Web Crawler for Scope Discovery.

## MongoDB and Redis

Tarantula provides MongoDB and Redis clients for persistent data and
queue/cache features. Start the local development services with Docker Compose:

```bash
docker compose up -d
```

MongoDB is available at `127.0.0.1:27017` and Redis at `127.0.0.1:6379`.
Install the Ruby dependencies with `bundle install`. The gem exposes lazy
clients through:

```ruby
Tarantula::Config::Mongo.client
Tarantula::Config::Redis.client
```

Set `MONGODB_URI` and `REDIS_URL` to use non-default services. Redis also
supports `REDIS_HOST`, `REDIS_PORT`, and `REDIS_DB` when `REDIS_URL` is unset.
Compose stores service data in named volumes; `docker compose down` preserves
it, while `docker compose down --volumes` removes it.


## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/tarantula. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/tarantula/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Tarantula project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/tarantula/blob/main/CODE_OF_CONDUCT.md).
