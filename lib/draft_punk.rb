require 'draft_punk/version'
require 'amoeba'
require 'activerecord/macros'
require 'helpers/helper_methods'

module DraftPunk
  class ConfigurationError < RuntimeError
    def initialize(message)
      @caller = caller[0]
      @message = message
    end
    def to_s
      "#{@caller} error: #{@message}"
    end
  end

  class ApprovedVersionIdError < ArgumentError
    def initialize(message=nil)
      @message = message
    end
    def to_s
      "this model doesn't have an approved_version_id column, so you cannot access its editable or approved versions. Add a column approved_version_id (Integer) to enable this tracking."
    end
  end

  class HistoricVersionCreationError < ArgumentError
    def initialize(message=nil)
      @message = message
    end
    def to_s
      "could not create previously-approved version: #{@message}"
    end
  end

  class DraftCreationError < ActiveRecord::RecordInvalid
    def initialize(message)
      @message = message
    end
    def to_s
      "the editable version failed to be created: #{@message}"
    end
  end
end

ActiveSupport.on_load(:active_record) do
  extend DraftPunk::Model::Macros
end
