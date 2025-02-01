# DraftPunk

DraftPunk allows editing of an editable copy of an ActiveRecord model and its associations.

When it's time to edit, an editable version is created in the same table as the object. You can specify which associations should also be edited and stored with that editable copy. All associations are stored in their native table.

When it's time to publish, any attributes changed on your editable object persist to the original object. All associated objects behave the same way. Any associated have_many objects which are deleted on the editable are deleted on the original object.

- [Usage](#usage)
  - [Enable Editable Object Creation](#enable-editable-creation)
  - [Association Editable Object](#association-editables) - including customization of which associations use editable copies
  - [Updating an editable](#updating-a-editables) - including controllers and forms
  - [Publish an editable](#publish-a-editables) - including controllers and forms
  - [Tracking editables](#tracking-editables) - methods to tell you if the object is an editable or is approved
- [What about the rest of the application? People are seeing editable copies!](#what-about-the-rest-of-the-application-people-are-seeing-editable-copies)
- Options
  - [When creating an editable](#when-creating-an-editable)
    - [Handling attributes with uniqueness validations](#handling-attributes-with-uniqueness-validations)
    - [Before create editable callback](#before-create-editable-callback)
    - [After create editable callback](#after-create-editable-callback)
  - [When publishing an editable copy](#when-publishing-an-editable-copy)
    - [Before publish editable callback](#before-publish-editable-callback)
    - [Customize which attributes are published](#customize-which-attributes-are-published)
  - [Storing approved version history](#storing-approved-version-history)
    - [Prevent historic versions from being saved](#prevent-historic-versions-from-being-saved)
- [Installation](#installation)
- [Testing the gem](#testing-the-gem)

## Usage

### Enable Editable Version Creation

To enable editable versions for a model, first add an approved_version_id column (Integer), which will be used to track its editable.

Simply call requires_approval in your model to enable DraftPunk on that model and its associations:

    class Business << ActiveRecord::Base
      has_many :employees
      has_many :images
      has_one  :address
      has_many :vending_machines

      requires_approval
    end

### Association Editables

**DraftPunk will generate editable versions for all associations**, by default. So when you create an editable Business, that copy will also have draft `employees`, `vending_machines`, `images`, and an `address`. **The whole tree is recursively duplicated.**

**Do not call `requires_approval` on Business's associated objects.** The behavior automatically cascades down until there are no more associations.

Optionally, you can tell DraftPunk which associations the user will edit - the associations which should have a copy created.

If you only want the :address association to have a copy created, add a `CREATES_NESTED_EDITABLES_FOR` constant in your model:

    CREATES_NESTED_EDITABLES_FOR = [:address] # When creating a business's editable copy, only :address will have a copy created

To disable drafts for all associations for this model, simply pass an empty array:

    CREATES_NESTED_EDITABLES_FOR = [] # When creating a business's draft, no associations will have copies created

**WARNING: If you are setting associations via `accepts_nested_attributes`** _all changes to the draft, including associations, get set on the
editable copy object (as expected). If your form includes associated objects which weren't defined in `requires_approval`, your save will fail since
the editable copy object doesn't HAVE those associations to update! In this case, you should probably add that association to the
`associations` param when you call `requires_approval`._

### Updating an editable

So you have an ActiveRecord object:

    @business = Business.first

And you want it's editable version - its copy:

    @my_editable = @business.editable_version   #If @business doesn't have an editable copy yet, it creates one for you.

Now you can edit the editable. Perhaps in your controller, you have:

    def edit
      @my_editable = @business.editable_version
      render 'form'
    end

In the view (or even in rails console), you'll want to be editing that copy version. For instance, pass your editable copy into the business's form, and it'll just work!

    form_for @my_editable

And, voila, the user is editing the editable.

Your update action might look like so:

    def update
      @my_editable = Business.find(params[:id])
      .... do some stuff here
    end

So your editable copy is automatically getting updated.

If your `@business` has a `name` attribute:

    @business.name
    => "DraftPunk LLC"

And you change your name:

    @my_editable = @business.editable_version
    @my_editable.name = "DraftPunk Inc"
    @my_editable.save

At this point, that change is only saved on the editable copy of your business. The original business still has the name DraftPunk LLC.

### Publish an editable

Publishing the editable copy publishes the copy's changes onto the approved version. The copy is then destroyed. Example:

So you want to make your changes live:

    @business.name
    => "DraftPunk LLC"
    @business.editable.name
    => "DraftPunk Inc"
    @business.publish_editable!
    @business.name
    => "DraftPunk Inc"

**All of the @business associations copied from the editable copy**. More correctly, the foreign_keys on has_many associations are changed, set to the original object (@business) id. All the old associations (specified in requires_approval) on @business are destroyed.

At this point, the editable copy is destroyed. Next time you call `editable_version`, an editable copy will be created for you.

### Tracking editable copies

Your original model has a few methods available:

    @business.id
    => 1
    @editable = @business.editable
    => Business(id: 2, ...)
    @editable.approved_version
    => Business(id: 1, ...)
    @editable.is_editable?
    => true
    @editable.has_editable?
    => false
    @business.is_editable?
    => false
    @business.has_editable?
    => true

Your associations can have this behavior, too, which could be useful in your application. If you want your editable copy associations to track their live version, add an `approved_version_id` column (Integer) to each table. You'll have all the methods demonstrated above. This also allows you to access a child association directly, ie.

    @live_image = @business.images.first
    => Image(id: 1, ...)
    @editable_image = @business.editable.images.first
    => Image(id: 2, ...)

At this point, if you don't have `approved_version_id` on the `images` table, there's no way for you to know that `@editable_image` was originally a copy of `@live_image`. If you have `approved_version_id` on your table, you can call:

    @editable_image.approved_version
    => Image(id: 1, ...)
    @live_image.editable
    => Image(id: 2, ...)

You now know for certain that the two are associated, which could be useful in your app.

### ActiveRecord scopes

All models which have `approved_version_id` also have these scopes: `approved` and `editable`.

## What about the rest of the application? People are seeing editable businesses!

You can implement this in a variety of ways. Here's two approaches:

### Set a Rails `default_scope` on your model.

This is the quickest, most DRY way to address this:

    default_scope Business.approved

Then, any ActiveRecord queries for Business will be scoped to only approved models. Your `editable` scope, and `editable` association will ignore this scope, so `@business.editable` and `Business.editable` will both continue to return editable copy objects.

### Or, modify your controllers to use the `approved` scope

Alternately, you may want to modify your controllers to only access _approved_ objects. For instance, your business controller should use that `approved` scope when it looks up businesses. i.e.

    class BusinessesController < ApplicationController
      def index
        @businesses = Business.approved.all
        ... more code
      end
    end

## Options

### When creating an editable copy

#### Before create editable callback

If you define a method on your model called `before_create_editable`, that method will be executed before the editable copy is created.

You can access `self` (which is the EDITABLE version being created), or the `temporary_approved_object` (the original object) in this method

    def before_create_editable
      logger.warn "#{self.name} is being created from #{temporary_approved_object.class.name} ##{temporary_approved_object.id}" # outputs: DerpCorp is being created from Business #1
    end

#### After create editable callback

If you define a method on your model called `after_create_editable`, that method will be executed before the editable copy is created. This is useful in cases when you need a fully set-up copy to modify. For instance, after all of its associations have been set.

You can access `self` (which is the EDITABLE version being created), or the `temporary_approved_object` (the original object) in this method

**Note that you are responsible for any saves needed**. `draft_punk` does not save again after your after_create executes

#### Handling attributes with uniqueness validations

When calling `requires_approval`, you can pass a `nullify` option to set attributes to null once the editable copy is created:

    requires_approval nullify: [:subdomain]

This could be useful if your model has an attribute which should not persist. In this example, each Business has a unique subdomain (ie. business_name.foo.com ). By nullifying this out, the subdomain on the editable copy would be nil.

### When publishing an editable copy

#### Before publish editable callback

If you define a method on your model called `before_publish_editable`, that method will be executed before the editable copy is published. Specifically, it happens after all attributes are copied from the editable copy to the approved version, and right before the approved version is saved. This allows you to do whatever you'd like to the model before it is saved.

#### After publish editable callback

If you define a method on your model called `after_publish_editable`, that method will be executed after the editable copy is published.

#### Customize which attributes are published

When an editable copy is published, most attributes are copied from the copy to the approved version. Naturally, created-at and id would not be copied.

You can control the whitelist of attributes to copy by defining `approvable_attributes` method in each model where you need custom behavior.

For instance, if each object has a unique `token` attributes, you may not want to copy that to the approved version upon publishing:

    def approvable_attributes
      self.attributes.keys - ["token"]
    end

    @business.token
    => '12345'
    @business.editable.token
    => 'abcde'
    @business.publish_editable!
    @business.token
    => '12345' # it was not changed

### TODO: Customizing Association associations (grandchildren) using accepts_nested_editables_for

### TODO: Customizing changes_require_approval

### Storing approved version history

You can optionally store the history of approved versions of an object. For instance:

    @business.name
    => "DraftPunk LLC"
    @business.editable.name
    => "DraftPunk Inc"
    @business.publish_editable!
    @business.editable.name = "DraftPunk Incorperated"
    => "DraftPunk Incorperated"
    @business.publish_editable!

    @business.name
    => "DraftPunk Incorperated"

    @business.previous_versions.pluck(:name)
    => ['DraftPunk Inc', 'DraftPunk LLC']

    @business.previous_versions
    => [Business(id: 2, name: 'DraftPunk Inc', ...), Business(id: 3, name: 'DraftPunk LLC', ...)]

To enable this feature, add a `current_approved_version_id` column (Integer) to the model you call `requires_approval` on. Version history will be automatically tracked if that column is present.

#### Prevent historic versions from being saved

Since these are historic versions, and not the editable copy or the current live/approved version, you may want to prevent saving. In your model, set the `allow_previous_versions_to_be_changed` option, which adds a `before_save` callback halting any save.

    requires_approval allow_previous_versions_to_be_changed: false

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'draft_punk'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install draft_punk

## Why this gem compared to similar gems?

I wrote this gem because other draft/publish gems had limitations that ruled them out in my use case. Here's a few reasons I ended up rolling my own:

1. This gem simply works with your existing database (plus one new column on your original object).
2. I tried using an approach that stores incremental changes in another table. For instance, some draft gems rely on a Versioning gem, or otherwise store incremental changes in the database.

   That gets super complicated, or simply don't work, with associations, nested associations, and/or if you want users to be able to _edit_ those changes.

3. This gem works with Rails `accepts_nested_attributes`. That Rails pattern doesn't work when you pass in objects which aren't associated; for instance, if you try to save a new draft image on your Blog post via nested_attributes, Rails will throw a 404 error. It got nasty, fast, so I needed a solution that worked well with Rails.
4. I prefer to store editable copies in the same table as the original. While this has a downside (see downsides, below), it means:

   1. Your editable copy acts like the original. You can execute all the same methods on it, reuse presenters, forms, form_objects, decorators, or anything else. It doesn't just quack like a duck, it **is** a duck.

   2. This prevents your table structure from getting out of sync. If you're using DraftPunk, when you add a new attribute to your model, or change a column, both your live/approved version and your draft version are affected. Using a different pattern, if they live in separate tables, you may need to run migrations on both tables (or, migrate the internals of a version diff if your draft gem relies on something like Paper Trail or VestalVersion)

### Downsides

Since DraftPunk saves in the same table as the original, your queries in those tables will return both approved and draft objects. In other words, without modifying your Rails app further, your BusinessController index action (in a typical rails app) will return drafts and approved objects. DraftPunk adds scopes to help you manage this. See the "What about the rest of the application? People are seeing editable copy businesses!" section below for two patterns to address this.

## Contributing

1. Fork it ( https://github.com/stevehodges/draft_punk/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Be consistent with the rest of this repo. Write thorough tests (rspec) and documentation (yard)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request

## Testing the gem

To test the gem against the current version of Rails (in [Gemfile.lock](Gemfile.lock)):

1. `bundle install`
2. `bundle exec rspec`

Or, you can run tests for all supported Rails versions

1. `gem install appraisal`
1. `bundle exec appraisal install` _(this Generates gemfiles for all permutations of our dependencies, so you'll see lots of bundler output))_
1. `bundle exec appraisal rspec`. _(This runs rspec for each dependency permutation. If one fails, appraisal exits immediately and does not test permutations it hasn't gotten to yet. Tests are not considered passing until all permutations are passing)_

If you only want to test a certain dependency set, such as Rails 5.2: `bundle exec appraisal rails-5-2 rspec`.

You can view all available dependency sets in [Appraisals](Appraisals)
