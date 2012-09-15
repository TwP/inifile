#encoding: UTF-8
require 'strscan'

# This class represents the INI file and can be used to parse, modify,
# and write INI files.
#
class IniFile
  include Enumerable

  class Error < StandardError; end
  VERSION = '2.0.2'

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

  # Get and set the encoding (Ruby 1.9)
  attr_accessor :encoding

  # Enable or disable character escaping
  attr_accessor :escape

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

    @comment  = opts.fetch(:comment, ';#')
    @param    = opts.fetch(:parameter, '=')
    @encoding = opts.fetch(:encoding, nil)
    @escape   = opts.fetch(:escape, true)
    @default  = opts.fetch(:default, 'global')
    @filename = opts.fetch(:filename, nil)

    @ini = Hash.new {|h,k| h[k] = Hash.new}

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
        hash.each {|param,val| f.puts "#{param} #{@param} #{escape_value val}"}
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
      hash.each {|param,val| s << "#{param} #{@param} #{escape_value val}"}
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

    string = ''
    property = ''

    @ini.clear
    @_line = nil
    @_section = nil

    scanner = StringScanner.new(@content)
    until scanner.eos?

      # keep track of the current line for error messages
      @_line = scanner.check(%r/\A.*$/) if scanner.bol?

      # look for escaped special characters \# \" etc
      if scanner.scan(%r/\\([\[\]#{@param}#{@comment}"])/)
        string << scanner[1]

      # look for quoted strings
      elsif scanner.scan(%r/"/)
        quote = scanner.scan_until(/(?:\A|[^\\])"/)
        parse_error('Unmatched quote') if quote.nil?

        quote.chomp!('"')
        string << quote

      # look for comments, empty strings, end of lines
      elsif scanner.skip(%r/\A\s*(?:[#{@comment}].*)?$/)
        string << scanner.getch unless scanner.eos?

        process_property(property, string)

      # look for the separator between property name and value
      elsif scanner.scan(%r/#{@param}/)
        if property.empty?
          property = string.strip
          string.slice!(0, string.length)
        else
          parse_error
        end

      # look for the start of a new section
      elsif scanner.scan(%r/\A\s*\[([^\]]+)\]/)
        @_section = @ini[scanner[1]]

      # otherwise scan and store characters till we hit the start of some
      # special section like a quote, newline, comment, etc.
      else
        tmp = scanner.scan_until(%r/([\n"#{@param}#{@comment}] | \z | \\[\[\]#{@param}#{@comment}"])/mx)
        parse_error if tmp.nil?

        len = scanner[1].length
        tmp.slice!(tmp.length - len, len)

        scanner.pos = scanner.pos - len
        string << tmp
      end
    end

    process_property(property, string)
  end

  # Store the property / value pair in the currently active section. This
  # method checks for continuation of the value to the next line.
  #
  # property - The property name as a String.
  # value    - The property value as a String.
  #
  # Returns nil.
  #
  def process_property( property, value )
    value.chomp!
    return if property.empty? and value.empty?
    return if value.sub!(%r/\\\s*\z/, '')

    property.strip!
    value.strip!

    parse_error if property.empty?

    current_section[property.dup] = unescape_value(value.dup)

    property.slice!(0, property.length)
    value.slice!(0, value.length)

    nil
  end

  # Returns the current section Hash.
  #
  def current_section
    @_section ||= @ini[@default]
  end

  # Raise a parse error using the given message and appending the current line
  # being parsed.
  #
  # msg - The message String to use.
  #
  # Raises IniFile::Error
  #
  def parse_error( msg = 'Could not parse line' )
    raise Error, "#{msg}: #{@_line.inspect}"
  end

  # Unescape special characters found in the value string. This will convert
  # escaped null, tab, carriage return, newline, and backslash into their
  # literal equivalents.
  #
  # value - The String value to unescape.
  #
  # Returns the unescaped value.
  #
  def unescape_value( value )
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
  def escape_value( value )
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

