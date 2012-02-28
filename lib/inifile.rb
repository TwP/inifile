#
# This class represents the INI file and can be used to parse, modify,
# and write INI files.
#

#encoding: UTF-8

class IniFile

  # Inifile is enumerable.
  include Enumerable

  # :stopdoc:
  class Error < StandardError; end
  VERSION = '1.0.0'
  # :startdoc:

  #
  # call-seq:
  #    IniFile.load( filename )
  #    IniFile.load( filename, options )
  #
  # Open the given _filename_ and load the contents of the INI file.
  # The following _options_ can be passed to this method:
  #
  #    :comment => ';'      The line comment character(s)
  #    :parameter => '='    The parameter / value separator
  #    :encoding => nil     The encoding used for read/write (RUBY 1.9)
  #    :escape => true      Whether or not to escape values when reading/writing
  #
  def self.load( filename, opts = {} )
    new(filename, opts)
  end

  #
  # call-seq:
  #    IniFile.new( filename )
  #    IniFile.new( filename, options )
  #
  # Create a new INI file using the given _filename_. If _filename_
  # exists and is a regular file, then its contents will be parsed.
  # The following _options_ can be passed to this method:
  #
  #    :comment => ';'      The line comment character(s)
  #    :parameter => '='    The parameter / value separator
  #    :encoding => nil     The encoding used for read/write (RUBY 1.9)
  #    :escape => true      Whether or not to escape values when reading/writing
  #
  def initialize( filename, opts = {} )
    @fn = filename
    @comment = opts.fetch(:comment, ';#')
    @param = opts.fetch(:parameter, '=')
    @encoding = opts.fetch(:encoding, nil)
    @escape = opts.fetch(:escape, true)
    @ini = Hash.new {|h,k| h[k] = Hash.new}

    @rgxp_comment = %r/\A\s*\z|\A\s*[#{@comment}]/
    @rgxp_section = %r/\A\s*\[([^\]]+)\]/
    @rgxp_param   = %r/[^\\]#{@param}/

    parse
  end

  #
  # call-seq:
  #    write
  #    write( filename )
  #
  # Write the INI file contents to the file system. The given _filename_
  # will be used to write the file. If _filename_ is not given, then the
  # named used when constructing this object will be used.
  # The following _options_ can be passed to this method:
  #
  #    :encoding => nil     The encoding used for writing (RUBY 1.9)
  #
  def write( filename = nil, opts={} )
    @fn = filename unless filename.nil?

    encoding = opts[:encoding] || @encoding
    mode = (RUBY_VERSION >= '1.9' && @encoding) ?
         "w:#{encoding.to_s}" :
         'w'

    File.open(@fn, mode) do |f|
      @ini.each do |section,hash|
        f.puts "[#{section}]"
        hash.each {|param,val| f.puts "#{param} #{@param} #{escape val}"}
        f.puts
      end
    end
    self
  end
  alias :save :write

  #
  # call-seq:
  #   to_s
  #
  # Convert IniFile to text format.
  #
  def to_s
    s = []
    @ini.each do |section,hash|
      s << "[#{section}]"
      hash.each {|param,val| s << "#{param} #{@param} #{escape val}"}
      s << ""
    end
    s.join("\n")
  end

  #
  # call-seq:
  #   to_h
  #
  # Convert IniFile to hash format.
  #
  def to_h
    @ini.dup
  end

  #
  # call-seq:
  #   merge( other_inifile )
  #
  # Returns a copy of this inifile with the entries from the other_inifile
  # merged into the copy.
  #
  def merge( other )
    self.dup.merge!(other)
  end

  #
  # call-seq:
  #   merge!( other_inifile )
  #
  # Merges other_inifile into this inifile, overwriting existing entries.
  # Useful for having a system inifile with user overridable settings elsewhere.
  #
  def merge!( other )
    my_keys = @ini.keys
    other_keys =
        case other
        when IniFile; other.instance_variable_get(:@ini).keys
        when Hash; other.keys
        else raise "cannot merge contents from '#{other.class.name}'" end

    (my_keys & other_keys).each do |key|
      @ini[key].merge!(other[key])
    end

    (other_keys - my_keys).each do |key|
      @ini[key] = other[key]
    end

    self
  end

  #
  # call-seq:
  #    each {|section, parameter, value| block}
  #
  # Yield each _section_, _parameter_, _value_ in turn to the given
  # _block_. The method returns immediately if no block is supplied.
  #
  def each
    return unless block_given?
    @ini.each do |section,hash|
      hash.each do |param,val|
        yield section, param, val
      end
    end
    self
  end

  #
  # call-seq:
  #    each_section {|section| block}
  #
  # Yield each _section_ in turn to the given _block_. The method returns
  # immediately if no block is supplied.
  #
  def each_section
    return unless block_given?
    @ini.each_key {|section| yield section}
    self
  end

  #
  # call-seq:
  #    delete_section( section )
  #
  # Deletes the named _section_ from the INI file. Returns the
  # parameter / value pairs if the section exists in the INI file. Otherwise,
  # returns +nil+.
  #
  def delete_section( section )
    @ini.delete section.to_s
  end

  #
  # call-seq:
  #    ini_file[section]
  #
  # Get the hash of parameter/value pairs for the given _section_. If the
  # _section_ hash does not exist it will be created.
  #
  def []( section )
    return nil if section.nil?
    @ini[section.to_s]
  end

  #
  # call-seq:
  #    ini_file[section] = hash
  #
  # Set the hash of parameter/value pairs for the given _section_.
  #
  def []=( section, value )
    @ini[section.to_s] = value
  end

  #
  # call-seq:
  #    ini_file.match( /section/ )    #=> hash
  #
  # Return a hash containing only those sections that match the given regular
  # expression.
  #
  def match( regex )
    @ini.dup.delete_if { |section, _| section !~ regex }
  end

  #
  # call-seq:
  #    has_section?( section )
  #
  # Returns +true+ if the named _section_ exists in the INI file.
  #
  def has_section?( section )
    @ini.has_key? section.to_s
  end

  #
  # call-seq:
  #    sections
  #
  # Returns an array of the section names.
  #
  def sections
    @ini.keys
  end

  #
  # call-seq:
  #    freeze
  #
  # Freeze the state of the +IniFile+ object. Any attempts to change the
  # object will raise an error.
  #
  def freeze
    super
    @ini.each_value {|h| h.freeze}
    @ini.freeze
    self
  end

  #
  # call-seq:
  #    taint
  #
  # Marks the INI file as tainted -- this will traverse each section marking
  # each section as tainted as well.
  #
  def taint
    super
    @ini.each_value {|h| h.taint}
    @ini.taint
    self
  end

  #
  # call-seq:
  #    dup
  #
  # Produces a duplicate of this INI file. The duplicate is independent of the
  # original -- i.e. the duplicate can be modified without changing the
  # original. The tainted state of the original is copied to the duplicate.
  #
  def dup
    other = super
    other.instance_variable_set(:@ini, Hash.new {|h,k| h[k] = Hash.new})
    @ini.each_pair {|s,h| other[s].merge! h}
    other.taint if self.tainted?
    other
  end

  #
  # call-seq:
  #    clone
  #
  # Produces a duplicate of this INI file. The duplicate is independent of the
  # original -- i.e. the duplicate can be modified without changing the
  # original. The tainted state and the frozen state of the original is copied
  # to the duplicate.
  #
  def clone
    other = dup
    other.freeze if self.frozen?
    other
  end

  #
  # call-seq:
  #    eql?( other )
  #
  # Returns +true+ if the _other_ object is equivalent to this INI file. For
  # two INI files to be equivalent, they must have the same sections with  the
  # same parameter / value pairs in each section.
  #
  def eql?( other )
    return true if equal? other
    return false unless other.instance_of? self.class
    @ini == other.instance_variable_get(:@ini)
  end
  alias :== :eql?

  #
  # call-seq:
  #   restore
  #
  # Restore data from the ini file. If the state of this object has been
  # changed but not yet saved, this will effectively undo the changes.
  #
  def restore
    parse
  end

private

  # Parse the ini file contents.
  #
  def parse
    return unless File.file?(@fn)

    @_current_section = nil
    @_current_param = nil
    @_current_value = nil

    fd = (RUBY_VERSION >= '1.9' && @encoding) ?
         File.open(@fn, 'r', :encoding => @encoding) :
         File.open(@fn, 'r')

    while line = fd.gets
      line = line.chomp

      # we ignore comment lines and blank lines
      if line =~ @rgxp_comment
        finish_property
        next
      end

      # place values in the current section
      if line =~ @rgxp_section
        finish_property
        @_current_section = @ini[$1.strip]
        next
      end

      parse_property line

    end  # while

    finish_property
  ensure
    fd.close if defined? fd and fd
    @_current_section = nil
    @_current_param = nil
    @_current_value = nil
  end

  # Attempt to parse a property name and value from the given _line_. This
  # method takes into account multi-line values.
  #
  def parse_property( line )
    p = v = nil
    split = line =~ @rgxp_param

    if split
      p = line.slice(0, split+1).strip
      v = line.slice(split+2, line.length).strip
    else
      v = line
    end

    if p.nil? and @_current_param.nil?
      raise Error, "could not parse line '#{line}'"
    end

    @_current_param = p unless p.nil?

    if @_current_value then @_current_value << v
    else @_current_value = v end

    finish_property unless @_current_value.sub!(%r/\\\z/, "\n")
  end

  # If there is a current property being parsed, finish this parse step by
  # storing the name and value in the current section and resetting for the
  # next parse step.
  #
  def finish_property
    return unless @_current_param

    raise Error, "parameter encountered before first section" if @_current_section.nil?
    @_current_section[@_current_param] = unescape @_current_value

    @_current_param = nil
    @_current_value = nil
  end

  # Unescape special characters found in the value string. This will convert
  # escaped null, tab, carriage return, newline, and backslash into their
  # literal equivalents.
  #
  def unescape( value )
    return value unless @escape

    value = value.to_s
    value.gsub!(%r/\\[0nrt\\]/) { |char|
      case char
      when '\0';   "\0"
      when '\n';   "\n"
      when '\r';   "\r"
      when '\t';   "\t"
      when '\\\\'; "\\"
      end
    }
    value
  end

  # Escape special characters
  #
  def escape( value )
    return value unless @escape

    value = value.to_s.dup
    value.gsub!(%r/\\([0nrt])/, '\\\\\1')
    value.gsub!(%r/\n/, '\n')
    value.gsub!(%r/\r/, '\r')
    value.gsub!(%r/\t/, '\t')
    value.gsub!(%r/\0/, '\0')
    value
  end

end  # IniFile

