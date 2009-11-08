#
# This class represents the INI file and can be used to parse, modify,
# and write INI files.
#
class IniFile

  # Inifile is enumerable.
  include Enumerable

  # :stopdoc:
  class Error < StandardError; end
  VERSION = '0.2.1'
  # :startdoc:

  #
  # call-seq:
  #    IniFile.load( filename )
  #    IniFile.load( filename, options )
  #
  # Open the given _filename_ and load the contetns of the INI file.
  # The following _options_ can be passed to this method:
  #
  #    :comment => ';'      The line comment character(s)
  #    :parameter => '='    The parameter / value separator
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
  #
  def initialize( filename, opts = {} )
    @fn = filename
    @comment = opts[:comment] || ';#'
    @param = opts[:parameter] || '='
    @ini = Hash.new {|h,k| h[k] = Hash.new}

    @rgxp_comment = %r/\A\s*\z|\A\s*[#{@comment}]/
    @rgxp_section = %r/\A\s*\[([^\]]+)\]/o
    @rgxp_param   = %r/\A([^#{@param}]+)#{@param}(.*)\z/

    parse
  end

  #
  # call-seq:
  #    write
  #    write( filename )
  #
  # Write the INI file contents to the filesystem. The given _filename_
  # will be used to write the file. If _filename_ is not given, then the
  # named used when constructing this object will be used.
  #
  def write( filename = nil )
    @fn = filename unless filename.nil?

    ::File.open(@fn, 'w') do |f|
      @ini.each do |section,hash|
        f.puts "[#{section}]"
        hash.each {|param,val| f.puts "#{param} #{@param} #{val}"}
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
      hash.each {|param,val| s << "#{param} #{@param} #{val}"}
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
  # orgiinal. The tainted state of the original is copied to the duplicate.
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
  # orgiinal. The tainted state and the frozen state of the original is copied
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
  #
  # call-seq
  #    parse
  #
  # Parse the ini file contents.
  #
  def parse
    return unless ::Kernel.test ?f, @fn
    section = nil

    ::File.open(@fn, 'r') do |f|
      while line = f.gets
        line = line.chomp

        case line
        # ignore blank lines and comment lines
        when @rgxp_comment: next

        # this is a section declaration
        when @rgxp_section: section = @ini[$1.strip]

        # otherwise we have a parameter
        when @rgxp_param
          begin
            section[$1.strip] = $2.strip
          rescue NoMethodError
            raise Error, "parameter encountered before first section"
          end

        else
          raise Error, "could not parse line '#{line}"
        end
      end  # while
    end  # File.open
  end

end  # class IniFile

# EOF
