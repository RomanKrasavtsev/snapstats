# Snapstats

With this gem you can track your user activity (devise feature only), slowest controllers, user browsers and platforms. It's like newrelic, but better ;)

How to install

1. Add in Gemfile `gem 'snapstats'`
2. In your routes.rb add `mount Snapstats::Engine, :at => '/snap' `
3. Visit http://localhost:3000:/snap

This project rocks and uses MIT-LICENSE.