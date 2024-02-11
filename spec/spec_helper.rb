$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_record'
# ActiveSupport::Deprecation.debug = true
require 'action_view'
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
require 'draft_punk'
require 'dummy_app/db_schema.rb'
require 'dummy_app/models'

def setup_model_approvals
  House.disable_approval!
  Room.disable_approval!
  House.requires_approval nullify: House::NULLIFY_ATTRIBUTES
end

def disable_all_approvals
  House.disable_approval!
  Room.disable_approval!
  Permit.disable_approval!
  Closet.disable_approval!
  TrimStyle.disable_approval!
end

# BECAUSE OF THE GEM'S COUPLING WITH ACTIVERECORD, THE TESTS
# INTENTIONALLY HIT THE DATABASE.

def setup_house_with_editable
  House.delete_all
  Room.delete_all
  Closet.delete_all
  ElectricalOutlet.delete_all
  Permit.delete_all
  @house = House.new(architectual_style: 'Ranch')

  room = Room.new(name: 'Living Room')
  room.custom_flooring_style = CustomFlooringStyle.new(name: 'hardwood')
  room.electrical_outlets << ElectricalOutlet.new(outlet_count: 4)
  room.electrical_outlets << ElectricalOutlet.new(outlet_count: 2)
  room.closets << Closet.new(style: 'wall')
  room.closets << Closet.new(style: 'walk-in')
  room.trim_styles << TrimStyle.new(style: 'crown')

  @house.rooms   << room
  @house.rooms   << Room.new(name: 'Entryway')
  @house.permits << Permit.new(permit_type: 'Construction')
  @house.save!

  @editable = @house.editable_version
end

def setup_editable_with_changes
  @editable.architectual_style = "Victorian"

  @editable_room = @editable.rooms.first
  @editable_room.name = 'Parlor'
  @editable_room.custom_flooring_style.update_column(:name, 'shag')

  closet = @editable_room.closets.where(style: 'wall').first
  closet.style = 'hidden'
  closet.save!

  @editable_room.closets << Closet.create(style: 'coat')

  @editable_room.closets.delete(@editable_room.closets.where(style: 'walk-in'))
  @editable_room.save!

  @editable.save!
  @editable = House.unscoped.find @editable.id
end

def set_house_architectual_style_to_lodge
  self.architectual_style = 'Lodge'
end
