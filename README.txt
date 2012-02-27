= inifile
    by Tim Pease
    http://codeforpeople.rubyforge.org/inifile

== DESCRIPTION:

This is a native Ruby package for reading and writing INI files.

Although made popular by Windows, INI files can be used on any system thanks
to their flexibility. They allow a program to store configuration data, which
can then be easily parsed and changed. Two notable systems that use the INI
format are Samba and Trac.
  
== SYNOPSIS:

An initialization file, or INI file, is a configuration file that contains
configuration data for Microsoft Windows based applications. Starting with
Windows 95, the INI file format was superseded but not entirely replaced by
a registry database in Microsoft operating systems.

Although made popular by Windows, INI files can be used on any system thanks
to their flexibility. They allow a program to store configuration data, which
can then be easily parsed and changed.

=== File Format

A typical INI file might look like this:

  [section1]

  ; some comment on section1
  var1 = foo
  var2 = doodle
  var3 = "multiline
  also possible"
 
  [section2]

  ; another comment
  var1 = baz
  var2 = shoodle


==== Format

This describes the elements of the INI file format:

* *Sections*: Section declarations start with '[' and end with ']' as in [section1] and [section2] above. And sections start with section declarations.
* *Parameters*: The "var1 = foo" above is an example of a parameter (also known as an item). Parameters are made up of a key ('var1'), equals sign ('='), and a value ('foo'). Multiline is support if value of parameter is enclosed by ".
* *Comments*: All the lines starting with a ';' are assumed to be comments, and are ignored.

==== Differences

The format of INI files is not well defined. Many programs interpret their
structure differently than the basic structure that was defined in the above
example. The following is a basic list of some of the differences:

* *Comments*: Programs like Samba accept either ';' or '#' as comments. Comments can be added after parameters with several formats.
* *Backslashes*: Adding a backslash '\' allows you to continue the value from one line to another. Some formats also allow various escapes with a '\', such as '\n' for newline.
* <b>Duplicate parameters</b>: Most of the time, you can't have two parameters with the same name in one section. Therefore one can say that parameters are local to the section. Although this behavior can vary between implementations, it is advisable to stick with this rule.
* <b>Duplicate sections</b>: If you have more than one section with the same name then the last section overrides the previous one. (Some implementations will merge them if they have different keys.)
* Some implementations allow ':' in place of '='.

=== This Package

This package supports the standard INI file format described in the *Format*
section above. The following differences are also supported:

* *Comments*: The comment character can be specified when an +IniFile+ is created. The comment character must be the first non-whitespace character on a line.
* *Backslashes*: Backslashes are not supported by this package. But multilines are. Enclose the param's value by ".
* <b>Duplicate parameters</b>: Duplicate parameters are allowed in a single section. The last parameter value is the one that will be stored in the +IniFile+.
* <b>Duplicate sections</b>: Duplicate sections will be merged. Parameters duplicated between to the two sections follow the duplicate parameters rule above.
* *Parameters*: The parameter separator character can be specified when an +IniFile+ is created.

== INSTALL:

  gem install inifile

== LICENSE:

MIT License
Copyright (c) 2006 - 2012

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
