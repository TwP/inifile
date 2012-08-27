#
# This class represents the INI file and can be used to parse, modify,
# and write INI files.
#

#encoding: UTF-8

class IniFile
  include Enumerable

  class Error < StandardError; end
  VERSION = '2.0.0'

  # Public: Open an INI file and load the contents.
  #
  # filename - The name of the fiel as a String
  # opts     - The Hash of options (default: {})
  #            :comment   - String containing the comment character(s)
  #            :parameter - String used to separate parameter and value
  #            :encoding  - Encoding String for reading / writing (Ruby 1.9)
  #            :escape    - Boolean used to control character escaping
  #            :default   - The String name of the default global section
  #
  # Examples
  #
  #   IniFile.load('file.ini')
  #   #=> IniFile instance
  #
  #   IniFile.load('does/not/exist.ini')
  #   #=> nil
  #
  # Returns an IniFile intsnace or nil if the file could not be opened.
  #
  def self.load( filename, opts = {} )
    return unless File.file? filename
    new(opts.merge(:filename => filename))
  end

  # Get and set the filename
  attr_accessor :filename

  # Public: Create a new INI file from the given content String which
  # contains the INI file lines. If the content are omitted, then the
  # :filename option is used to read in the content of the INI file. If
  # neither the content for a filename is provided then an empty INI file is
  # created.
  #
  # content - The String containing the INI file contents
  # opts    - The Hash of options (default: {})
  #           :comment   - String containing the comment character(s)
  #           :parameter - String used to separate parameter and value
  #           :encoding  - Encoding String for reading / writing (Ruby 1.9)
  #           :escape    - Boolean used to control character escaping
  #           :default   - The String name of the default global section
  #           :filename  - The filename as a String
  #
  # Examples
  #
  #   IniFile.new
  #   #=> an empty IniFile instance
  #
  #   IniFile.new( "[global]\nfoo=bar" )
  #   #=> an IniFile instance
  #
  #   IniFile.new( :filename => 'file.ini', :encoding => 'UTF-8' )
  #   #=> an IniFile instance
  #
  #   IniFile.new( "[global]\nfoo=bar", :comment => '#' )
  #   #=> an IniFile instance
  #
  def initialize( content = nil, opts = {} )
    opts, content = content, nil if Hash === content

    @content = content
    @comment = opts.fetch(:comment, ';#')
    @param = opts.fetch(:parameter, '=')
    @encoding = opts.fetch(:encoding, nil)
    @escape = opts.fetch(:escape, true)
    @default = opts.fetch(:default, 'global')
    @filename = opts.fetch(:filename, nil)
    @ini = Hash.new {|h,k| h[k] = Hash.new}

    @rgxp_comment = %r/\A\s*\z|\A\s*[#{@comment}]/
    @rgxp_section = %r/\A\s*\[([^\]]+)\]/
    @rgxp_param   = %r/[^\\]#{@param}/

    if    @content  then parse!
    elsif @filename then read
    end
  end

  # Public: Write the contents of this IniFile to the file system. If left
  # unspecified, the currently configured filename and encoding will be used.
  # Otherwise the filename and encoding can be specified in the options hash.
  #
  # opts - The default options Hash
  #        :filename - The filename as a String
  #        :encoding - The encoding as a String (Ruby 1.9)
  #
  # Returns this IniFile instance.
  #
  def write( opts = {} )
    filename = opts.fetch(:filename, @filename)
    encoding = opts.fetch(:encoding, @encoding)
    mode = (RUBY_VERSION >= '1.9' && encoding) ?
         "w:#{encoding.to_s}" :
         'w'

    File.open(filename, mode) do |f|
      @ini.each do |section,hash|
        f.puts "[#{section}]"
        hash.each {|param,val| f.puts "#{param} #{@param} #{escape val}"}
        f.puts
      end
    end

    self
  end
  alias :save :write

  # Public: Read the contents of the INI file from the file system and replace
  # and set the state of this IniFile instance. If left unspecified the
  # currently configured filename and encoding will be used when reading from
  # the file system. Otherwise the filename and encoding can be specified in
  # the options hash.
  #
  # opts - The default options Hash
  #        :filename - The filename as a String
  #        :encoding - The encoding as a String (Ruby 1.9)
  #
  # Returns this IniFile instance if the read was successful; nil is returned
  # if the file could not be read.
  #
  def read( opts = {} )
    filename = opts.fetch(:filename, @filename)
    encoding = opts.fetch(:encoding, @encoding)
    return unless File.file? filename

    mode = (RUBY_VERSION >= '1.9' && encoding) ?
           "r:#{encoding.to_s}" :
           'r'
    fd = File.open(filename, mode)
    @content = fd.read

    parse!
    self
  ensure
    fd.close if fd && !fd.closed?
  end
  alias :restore :read

  # Returns this IniFile converted to a String.
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

  # Returns this IniFile converted to a Hash.
  #
  def to_h
    @ini.dup
  end

  # Public: Creates a copy of this inifile with the entries from the
  # other_inifile merged into the copy.
  #
  # other - The other IniFile.
  #
  # Returns a new IniFile.
  #
  def merge( other )
    self.dup.merge!(other)
  end

  # Public: Merges other_inifile into this inifile, overwriting existing
  # entries. Useful for having a system inifile with user over-ridable settings
  # elsewhere.
  #
  # other - The other IniFile.
  #
  # Returns this IniFile.
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

  # Public: Yield each INI file section, parameter, and value in turn to the
  # given block.
  #
  # block - The block that will be iterated by the each method. The block will
  #         be passed the current section and the parameter / value pair.
  #
  # Examples
  #
  #   inifile.each do |section, parameter, value|
  #     puts "#{parameter} = #{value} [in section - #{section}]"
  #   end
  #
  # Returns this IniFile.
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

  # Public: Yield each section in turn to the given block.
  #
  # block - The block that will be iterated by the each method. The block will
  #         be passed the current section as a Hash.
  #
  # Examples
  #
  #   inifile.each_section do |section|
  #     puts section.inspect
  #   end
  #
  # Returns this IniFile.
  #
  def each_section
    return unless block_given?
    @ini.each_key {|section| yield section}
    self
  end

  # Public: Remove a section identified by name from the IniFile.
  #
  # section - The section name as a String.
  #
  # Returns the deleted section Hash.
  #
  def delete_section( section )
    @ini.delete section.to_s
  end

  # Public: Get the section Hash by name. If the section does not exist, then
  # it will be created.
  #
  # section - The section name as a String.
  #
  # Examples
  #
  #   inifile['global']
  #   #=> global section Hash
  #
  # Returns the Hash of parameter/value pairs for this section.
  #
  def []( section )
    return nil if section.nil?
    @ini[section.to_s]
  end

  # Public: Set the section to a hash of parameter/value pairs.
  #
  # section - The section name as a String.
  # value   - The Hash of parameter/value pairs.
  #
  # Examples
  #
  #   inifile['tenderloin'] = { 'gritty' => 'yes' }
  #   #=> { 'gritty' => 'yes' }
  #
  # Returns the value Hash.
  #
  def []=( section, value )
    @ini[section.to_s] = value
  end

  # Public: Create a Hash containing only those INI file sections whose names
  # match the given regular expression.
  #
  # regex - The Regexp used to match section names.
  #
  # Examples
  #
  #   inifile.match(/^tree_/)
  #   #=> Hash of matching sections
  #
  # Return a Hash containing only those sections that match the given regular
  # expression.
  #
  def match( regex )
    @ini.dup.delete_if { |section, _| section !~ regex }
  end

  # Public: Check to see if the IniFile contains the section.
  #
  # section - The section name as a String.
  #
  # Returns true if the section exists in the IniFile.
  #
  def has_section?( section )
    @ini.has_key? section.to_s
  end

  # Returns an Array of section names contained in this IniFile.
  #
  def sections
    @ini.keys
  end

  # Public: Freeze the state of this IniFile object. Any attempts to change
  # the object will raise an error.
  #
  # Returns this IniFile.
  #
  def freeze
    super
    @ini.each_value {|h| h.freeze}
    @ini.freeze
    self
  end

  # Public: Mark this IniFile as tainted -- this will traverse each section
  # marking each as tainted.
  #
  # Returns this IniFile.
  #
  def taint
    super
    @ini.each_value {|h| h.taint}
    @ini.taint
    self
  end

  # Public: Produces a duplicate of this IniFile. The duplicate is independent
  # of the original -- i.e. the duplicate can be modified without changing the
  # original. The tainted state of the original is copied to the duplicate.
  #
  # Returns a new IniFile.
  #
  def dup
    other = super
    other.instance_variable_set(:@ini, Hash.new {|h,k| h[k] = Hash.new})
    @ini.each_pair {|s,h| other[s].merge! h}
    other.taint if self.tainted?
    other
  end

  # Public: Produces a duplicate of this IniFile. The duplicate is independent
  # of the original -- i.e. the duplicate can be modified without changing the
  # original. The tainted state and the frozen state of the original is copied
  # to the duplicate.
  #
  # Returns a new IniFile.
  #
  def clone
    other = dup
    other.freeze if self.frozen?
    other
  end

  # Public: Compare this IniFile to some other IniFile. For two INI files to
  # be equivalent, they must have the same sections with the same parameter /
  # value pairs in each section.
  #
  # other - The other IniFile.
  #
  # Returns true if the INI files are equivalent and false if they differ.
  #
  def eql?( other )
    return true if equal? other
    return false unless other.instance_of? self.class
    @ini == other.instance_variable_get(:@ini)
  end
  alias :== :eql?


private

  # Parse the ini file contents. This will clear any values currently stored
  # in the ini hash.
  #
  def parse!
    return unless @content

    @_current_section = nil
    @_current_param = nil
    @_current_value = nil
    @ini.clear

    @content.each_line do |line|
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

    end  # each_line

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
  # line - The String containing the line to parse.
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

    @_current_section = @ini[@default] if @_current_section.nil?
    @_current_section[@_current_param] = unescape @_current_value

    @_current_param = nil
    @_current_value = nil
  end

  # Unescape special characters found in the value string. This will convert
  # escaped null, tab, carriage return, newline, and backslash into their
  # literal equivalents.
  #
  # value - The String value to unescape.
  #
  # Returns the unescaped value.
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

  # Escape special characters.
  #
  # value - The String value to escape.
  #
  # Returns the escaped value.
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

