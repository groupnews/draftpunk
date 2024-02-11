
module DraftPunk
  module Model
    module EditableDiffInstanceMethods
      require 'differ'
      # Return the differences between the live and editable object.
      #
      # If include_associations is true, it will return the diff for all child associations, recursively until it gets
      # to the bottom of your draft tree. This only works for associations which have the approved_version_id column
      #
      # @param include_associations [Boolean] include diff for child objects, recursive (possibly down to grandchildren and beyond)
      # @param include_all_attributes [Boolean] return all attributes in the results, including those which have not changed
      # @param include_diff [Boolean] include an html formatted diff of changes between the live and editable, for each attribute
      # @param diff_format [Symbol] format the diff output per the options available in differ (:html, :ascii, :color)
      # @return (Hash)
      def editable_diff(include_associations: false, parent_object_fk: nil, include_all_attributes: false, include_diff: false, diff_format: :html, recursed: false)
        editable_obj = recursed ? editable : get_editable # get_editable will create missing drafts. Based on the logic, this should only happen when you *first* call editable_diff
        get_object_changes(self, editable_obj, include_associations, parent_object_fk, include_all_attributes, include_diff, diff_format)
      end

    protected #################################################################
      def current_approvable_attributes
        attribs = {}
        attributes.each do |k,v|
          attribs[k] = v if k.in?(diff_relevant_attributes)
        end
      end

    private ####################################################################

      def get_object_changes(approved_obj, editable_obj, include_associations, parent_object_fk, include_all_attributes, include_diff, diff_format)
        diff = {}
        approved_attribs = approved_obj ? approved_obj.current_approvable_attributes : {}
        editable_attribs    = editable_obj    ? editable_obj.current_approvable_attributes    : {}
        diff_relevant_attributes(parent_object_fk).each do |attrib|
          live     = approved_attribs[attrib]
          editable = editable_attribs[attrib]
          if include_all_attributes || live != editable
            diff[attrib] = {live: live, editable: editable}
            diff[attrib].merge!({diff: Differ.diff_by_word(editable, live).format_as(diff_format)}) if include_diff && (live.present? && editable.present? && live.is_a?(String) && editable.is_a?(String))
          end
        end
        diff.merge!(editable_status: :deleted) if parent_object_fk.present? && editable_attribs[parent_object_fk].nil?
        diff.merge!(associations_diff(include_all_attributes, include_diff, diff_format)) if include_associations
        diff[:editable_status] = diff_status(diff, parent_object_fk) unless diff.has_key?(:editable_status)
        diff[:class_info]   = {table_name: approved_obj.class.table_name, class_name: approved_obj.class.name}
        diff
      end

      def associations_diff(include_all_attributes, include_diff, diff_format)
        diff = {}
        self.class.editable_target_associations.each do |assoc|
          next unless association_tracks_approved_version?(assoc)
          diff[assoc] = []
          editable_versions = editable.present? ? [editable.send(assoc)].flatten.compact : []
          approved_versions = [get_approved_version.send(assoc)].flatten.compact
          foreign_key = self.class.reflect_on_association(assoc).foreign_key

          approved_versions.each do |approved|
            obj_diff = approved.editable_diff(include_associations: true, parent_object_fk: foreign_key, include_all_attributes: include_all_attributes, include_diff: include_diff, diff_format: diff_format, recursed: true)
            obj_diff.merge(editable_status: :deleted) unless editable_versions.find{|obj| obj.approved_version_id == approved.id }
            diff[assoc] << obj_diff if (include_all_attributes || obj_diff[:editable_status] != :unchanged)
          end
          editable_versions.select{|obj| obj.approved_version_id.nil? }.each do |editable|
            diff[assoc] << editable.editable_diff(include_associations: true, include_all_attributes: include_all_attributes, recursed: true).merge(editable_status: :added)
          end
        end
        diff.select{|k,v| v.present? || include_all_attributes}
      end

      def diff_status(diff, parent_object_fk)
        return if diff.has_key?(:status)
        diff.each do |attrib, value|
          if value.is_a?(Hash) && !attrib.in?([parent_object_fk.to_s, 'id'])
            return :changed unless value[:live] == value[:editable]
          end
        end
        :unchanged
      end

      def diff_relevant_attributes(parent_object_fk=nil)
        (usable_approvable_attributes + ['id'] - ['updated_at', 'approved_version_id', parent_object_fk]).map(&:to_s).uniq.compact
      end

    end
  end
end
