# Rack::Params

`Rack::Request.params` validation and type coercion, on Rack.

```ruby
# example uses Nancy, because plain Rack is ugly
# nothing about Rack::Params requires Nancy or any other framework.

class MyApp < Nancy::Base
  include Rack::Params

  # can create named validators that can be run at any time
  
  validator :document do
    param :id,      Integer,  required: true
    param :title,   String,   required: true
    param :created, DateTime
    
    param :tags, Array, default: ['a', 'b', 'c'] do
      every Symbol
    end
    
    param :content, Hash, required: true do
      param :header, String
      param :body,   String
    end
  end
  
  post "/doc/" do
    validate :document
    
    # params is now converted
    
    assert params[:id]   == 38
    assert params[:tags] ==
  end
  
  put "/:id/star" do |id|
    validate do
      params :id,      Integer
      params :starred, :boolean
    end
    
    fail "bad parameters!" if params.invalid?
    params.errors[:id] = ['something went wrong']
  end
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rack-params'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-params

## Usage

**[RDoc @ master - Rack::Params](http://www.rudydoc.info/github/lygaret/master)**

1. Include `Rack::Params` to get the `.validator`, `#validate` and `#validate!` methods.
2. Call `.validator(name, options = {}, &code)` to register a named validator for use later.
3. Call `#validate(name = nil, params = request.params, options = {}, &code)` to build a new result, with the results of validation and coercion.
4. The blocks passed to the validation methods run in the context of `HashContext` and `ArrayContext`, which is where the coercion methods are defined.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lygaret/rack-params.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Authors

* Jon Raphaelson - https://accidental.cc
* Based heavily on [`mattt/sinatra-param`](https://github.com/mattt/sinatra-param), though diverging significantly in ways.
