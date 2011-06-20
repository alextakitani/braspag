source "http://rubygems.org"

gem "httpi", :git => "https://github.com/tinogomes/httpi.git"

group :test do
  gem "ruby-debug19", :require => "ruby-debug", :platform => :ruby_19
  gem "ruby-debug", :platform => :jruby
  gem "fakeweb"
  gem "rspec" 
  gem "shoulda-matchers"
  gem "nokogiri"
  gem "guard-rspec"

   if RUBY_PLATFORM =~ /darwin/i
    gem "growl"
    gem 'rb-fsevent', :require => false
  elsif RUBY_PLATFORM =~ /linux/i
    gem "libnotify"
    gem "rb-inotify"
  end
end