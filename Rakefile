# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  begin
    load 'tasks/setup.rb'
  rescue LoadError
    raise RuntimeError, '### please install the "bones" gem ###'
  end
end

ensure_in_path 'lib'
require 'inifile'

task :default => 'test:run'

PROJ.name = 'inifile'
PROJ.summary = 'INI file reader and writer'
PROJ.authors = 'Tim Pease'
PROJ.email = 'tim.pease@gmail.com'
PROJ.url = 'http://codeforpeople.rubyforge.org/inifile'
PROJ.version = IniFile::VERSION
PROJ.rubyforge.name = 'codeforpeople'
PROJ.ignore_file = '.gitignore'
PROJ.rdoc.remote_dir = 'inifile'

PROJ.ann.email[:server] = 'smtp.gmail.com'
PROJ.ann.email[:port] = 587
PROJ.ann.email[:from] = 'Tim Pease'

# EOF
