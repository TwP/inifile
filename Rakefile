# $Id$

load 'tasks/setup.rb'

ensure_in_path 'lib'
require 'inifile'

task :default => 'test:run'

PROJ.name = 'inifile'
PROJ.summary = 'INI file reader and writer'
PROJ.authors = 'Tim Pease'
PROJ.email = 'tim.pease@gmail.com'
PROJ.url = 'http://codeforpeople.rubyforge.org/inifile'
PROJ.description = paragraphs_of('README.txt', 1).join("\n\n")
PROJ.changes = paragraphs_of('History.txt', 0..1).join("\n\n")
PROJ.rubyforge_name = 'codeforpeople'
PROJ.version = IniFile::VERSION

PROJ.rdoc_remote_dir = PROJ.name
PROJ.svn = PROJ.name

# EOF
