
require 'hoe'

PKG_VERSION = ENV['VERSION'] || '0.0.0'

Hoe.new('inifile', PKG_VERSION) do |proj|
  proj.rubyforge_name = 'codeforpeople.com'
  proj.author = 'Tim Pease'
  proj.email = 'tim.pease@gmail.com'
  proj.url = nil
  proj.extra_deps = []
  proj.clean_globs << 'coverage'
  proj.summary = 'INI file reader and writer'
  proj.description = <<-DESC
Although made popular by Windows, INI files can be used on any system thanks
to their flexibility. They allow a program to store configuration data, which
can then be easily parsed and changed. Two notable systems that use the INI
format are Samba and Trac.

This is a native Ruby package for reading and writing INI files.
  DESC
  proj.changes = <<-CHANGES
Version 0.1.0 / 2006-11-26
  * initial release
  CHANGES
end

# --------------------------------------------------------------------------
desc 'Run rcov on the unit tests'
task :coverage do
  opts = "-x turn\\\\.rb\\\\z -T --sort coverage --no-html"
  sh "rcov -Ilib test/test_inifile.rb #{opts}"
end

# EOF
