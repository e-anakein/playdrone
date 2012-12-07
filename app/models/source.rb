class Source
  include Tire::Model::Persistence

  property :apk_eid
  property :path
  property :lib
  property :lines
  property :num_lines
  property :size

  tire.mapping :_all => {:enabled => false} do
    indexes :apk_eid,   :index    => :not_analyzed, :store => :yes
    indexes :path,      :index    => :not_analyzed, :store => :yes
    indexes :lib,       :index    => :not_analyzed, :store => :yes
    indexes :lines,     :analyzer => :simple
    indexes :num_lines, :type     => :integer, :store => :yes
    indexes :size,      :type     => :integer, :store => :yes
  end

  def self.index_sources!(apk)
    base_len = nil

    sources = []
    apk.source_dir.find do |f|
      base_len = f.to_s.size if base_len.nil?

      if f.file? && f.extname == '.java'
        lines = f.open.lines.map(&:chomp)
        sources << new(:id        => Moped::BSON::ObjectId.new.to_s,
                       :apk_eid   => apk.eid,
                       :path      => f.to_s[base_len+1..-1],
                       :lines     => lines,
                       :num_lines => lines.count,
                       :size      => f.size)
      end
    end

    index.import sources
    true
  end

  def self.purge_index!(apk)
    Tire::Configuration.client.delete "#{index.url}/_query?q=apk_eid:#{apk.eid}"
  end

  def self.search_path(query, options={})
    size  = options[:size] || 10
    field = options[:field] || :path

    res = tire.search(:per_page => 0) do
      query { query == '*' ? all : @value = { :wildcard => { :path => query } } }
      facet(field) { terms :field => field, :size => size }
    end

    {
      :total  => res.total,
      :detail => Hash[res.facets[field.to_s]['terms'].map { |f| [f['term'], f['count']] }]
    }
  end

  def self.search(query, options={})
    tire.search(options) do
      query     { string query, :default_field => :lines, :default_operator => 'AND' }
      highlight :lines => {:fragment_size => 300, :number_of_fragments => 100000}, :options => {:tag => ''}
      fields    :apk_eid, :path

      facet(:num_lines) { statistical :num_lines }
      facet(:size)      { statistical :size }
    end
  end

  def self.filter_lines(results, regex=nil)
    per_file_lines = []
    results.each do |source|
      next unless source.highlight
      matched_lines = source.highlight[:lines]
      matched_lines = matched_lines.grep(regex) if regex
      next if matched_lines.empty?

      per_file_lines << {:apk_eid => source.apk_eid,
                         :path    => source.path,
                         :lines   => matched_lines}
    end
    per_file_lines
  end
end