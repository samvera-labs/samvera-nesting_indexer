# rubocop:disable Style/FileName
require 'samvera/nesting_indexer'
# rubocop:enable Style/FileName

Samvera::NestingIndexer.configure do |config|
  # How many layers of nesting are allowed for collections
  # Given a maximum_nesting_depth of 3 the following will raise an exception:
  # C1 ={ C2 ={ C3 ={ C4
  # (e.g. C4 is a member of C3 is a member of C2 is a member of C1)
  config.maximum_nesting_depth = <%= @maximum_nesting_depth %>

  # The adapter that implements the Samvera::NestingIndexer::Adapter interface
  <%- if @adapter_class_name.blank? -%>
  # config.adapter = Hyrax::Adapters::NestingIndexAdapter
  <%- else -%>
  config.adapter = <%= @adapter_class_name %>
  <%- end -%>

  # The field names of the index layer attributes; These are not used by Samvera::NestingIndexer but
  # are certainly useful as part of implementing a Samvera::NestingIndexer::Adapter interface
  # config.solr_field_name_for_storing_parent_ids = Solrizer.solr_name('nesting_collection__parent_ids', :symbol)
  # config.solr_field_name_for_storing_ancestors =  Solrizer.solr_name('nesting_collection__ancestors', :symbol)
  # config.solr_field_name_for_storing_pathnames =  Solrizer.solr_name('nesting_collection__pathnames', :symbol)
  # config.solr_field_name_for_deepest_nested_depth =  Solrizer.solr_name('nesting_collection__deepest_nested_depth', :integer)
end
