#!ruby
VERSION = '7.22.200127'

### Standard Libraries ###

require 'find'
require 'open3'
require 'fileutils'
require 'singleton'
require 'date'

### Gems ###

require 'helpema'
HELPEMA::Helpema.requires <<GEMS
  colorize ~>0.8
GEMS

### Project's constants ###

TODO         = 'TODO.txt'
README       = 'README.md'
HISTORY      = 'History.txt'
THOR_VERSION = 'Thor 1.0.1'

### Helpers ###

# Exit messages
module EXIT
  ERRMSG = {
    64 => 'Usage',
    73 => 'CantCreat',
    69 => 'Unavailable',
    65 => 'DataErr',
    70 => 'Software',
    76 => 'Protocol',
  }
  def EXIT.message(msg, errno, file, line, method)
    who = "#{File.basename(file)}, ##{line}, #{method}"
    STDERR.puts "#{ERRMSG[errno]}: #{who.red}: #{msg}"
    exit errno # Usage Error
  end
  def EXIT.usage(msg)
    EXIT.message(msg, 64, *caller[0].split(/:/))
  end
  def EXIT.couldnt(msg)
    EXIT.message(msg, 73, *caller[0].split(/:/))
  end
  def EXIT.unavailable(msg)
    EXIT.message(msg, 69, *caller[0].split(/:/))
  end
  def EXIT.dataerr(msg)
    EXIT.message(msg, 65, *caller[0].split(/:/))
  end
  def EXIT.software(msg) # AKA Bug!
    EXIT.message(msg, 70, *caller[0].split(/:/))
  end
  def EXIT.protocol(msg) # WTF!?
    EXIT.message(msg, 76, *caller[0].split(/:/))
  end
end

module GIT
  def GIT.diff
    system 'git diff --minimal --ignore-space-change'
  end

  def GIT.commit_all
    system 'git commit -a'
  end

  def GIT.push
    system 'git push'
  end

  def GIT.tag_list
    `git tag --list`.strip.split("\n")
  end

  def GIT.status_porcelain
    `git status --porcelain`.strip
  end

  def GIT.status
    `git status`.strip
  end

  def GIT.user_name
    `git config user.name`.strip
  end

  def GIT.user_email
    `git config user.email`.strip
  end

  LS_FILES = 'git ls-files'
  def GIT.ls_files
    filter, gemig = '', '.gemignore'
    if File.exist?(gemig)
      filter = File.read(gemig).strip.gsub(/\s+/,'')
      filter = " | egrep -v '#{filter}'"
    end
    `#{LS_FILES}#{filter}`.strip
  end

  def GIT.commit_and_push(tag)
    system("git commit -a -m '#{tag}'")   or EXIT.couldnt   "git could not commit"
    system("git tag '#{tag}'")            or EXIT.couldnt   "git could not tag"
    system('git push')                    or EXIT.unavaible "git could not push"
  end
end

### Project attributes ###

class Project
  include Singleton

  ATTRIBUTES = [
    :wd,
    :readme,      :description, :summary,
    :name,        :gemspec,     :version,
    :date,
    :author,      :email,
    :gems,        :pkgems,
  ]
  attr_reader(*ATTRIBUTES)

  def attributes
    ATTRIBUTES
  end

  def initialize(wd=Dir.getwd)
    @wd = wd

    @readme      = README
    description  = File.read(@readme).match(/\n#+\s*DESCRIPTION:?(.*?)\n#/mi)[1].strip
    @description = description.split(/\n\n/)[0..1].join("\n\n").strip
    @summary     = description.split(/\n\n/).first.strip

    @name        = File.basename(@wd).split(/\-/).first
    @gemspec     = "#{@name}.gemspec"

    @version     = `egrep '^\\s*VERSION\\s*=' lib/*.rb 2> /dev/null`.match(/(\d+\.\d+\.\d+)/)[1]

    @date        = Date.today.to_s

    @author      = GIT.user_name
    @email       = GIT.user_email

    @gems        = Dir.glob('*.gem')
    @pkgems      = Dir.glob('pkg/*.gem')
  end

  def gems!
    @gems = Dir.glob('*.gem')
  end

  def uniq
    EXIT.software "Did not get unique gem file" unless gems!.length == 1
    @gems.first
  end

  def pkgems!
    @pkgems = Dir.glob('pkg/*.gem')
  end

  def [](attr)
    self.method(attr).call
  end
end

### Thor sub-classes ###

class Magni < Thor
  class << Magni; attr_accessor :warned; end
  Magni.warned = false

  def initialize(*params)
    super
    @wd = Dir.getwd
    warnings = proc { get_warnings }
    ObjectSpace.define_finalizer(self, warnings)
  end

  private

  def get_warnings
    unless Magni.warned
      Magni.warned =_= true
      goto_martelo
      puts _.yellow  unless (_=GIT.status_porcelain) == ''
      goto_wd
      puts _.yellow  unless (_=`thor version`.strip) == THOR_VERSION
    end
  end

  def goto_martelo
    # This file, lib/martelo.rb, is expected to be symlinked by tasks.thor.
    # Thor will see __FILE__ as tasks.thor, so goto tasks.thor's directory.
    Dir.chdir File.dirname __FILE__
    # Now read the symlink to get martelo's git directory and goto it.
    Dir.chdir File.dirname File.dirname File.expand_path File.readlink __FILE__
  end

  def goto_wd
    Dir.chdir @wd
  end
end

class Tasks < Magni
  desc 'commit', "commits tasks.thor's edits"
  def commit
    goto_martelo
    GIT.commit_all and GIT.push
    goto_wd
  end

  desc 'diff', "tasks.thor's `git diff`"
  long_desc <<-LONGDESC
    tasks.thor's file links to lib/martelo.rb's git.
    Edits to tasks.thor are done in this git.
    Use tasks:diff to diff the git.
  LONGDESC
  def diff
    goto_martelo
    GIT.diff
    goto_wd
  end

  desc 'edit', 'Edit tasks.thor'
  def edit
    system "vim #{__FILE__}"
    system "ruby -c #{__FILE__}"
  end

  desc 'revert', "reverts to tasks.thor's last commit"
  def revert
    goto_martelo
    system 'git checkout lib/martelo.rb'
    goto_wd
  end
end

# git command wraps
class Git < Magni
  desc 'commit_and_push "tag"', 'git commit and push with tag'
  def commit_and_push(tag)
    EXIT.usage "'#{tag}' in git tag list" if GIT.tag_list.include?(tag)
    GIT.commit_and_push(tag)
  end
end

# gem command wraps
class Gem < Magni

  def self.which(lib)
    `gem which '#{lib}'`
  end

  def self.version(lib)
    if Gem.which(lib)=~/\b([\w\-]+)-(\d+\.\d+(\.\d+)?)\b/
      return $1, $2
    end
    return lib, nil
  end

  def self.build
    project = Project.instance
    EXIT.dataerr "Found gem files in working directory" unless project.gems.length == 0
    EXIT.dataerr "Git status not clear" unless GIT.status_porcelain.length == 0
    gemspec = project.gemspec
    system("gem build #{gemspec}") or EXIT.couldnt "Could not build gem"
  end
  desc "build", "Builds gem from gemspec"
  def build
    Gem.build
  end

  def self.push(version)
    gem = Project.instance.uniq
    EXIT.software "#{version} did not match gem file" unless gem.include?(version)
    pkgem = File.join('pkg', gem)
    EXIT.protocol "#{pkgem} exists!?" if File.exist?(pkgem)
    if system "gem push #{gem}"
      File.rename gem, pkgem
      Write.add_history(pkgem)
    else
      EXIT.unavailable "Could not push #{gem}"
    end
  end
end

class Write < Magni
  def self.help(io=STDOUT)
    `ruby -I ./lib ./bin/#{Project.instance.name} -h`.split(/\n/).each do |line|
      if line.length > 0
        io.print '    $ '
        io.puts line
      end
    end
  end

  desc 'help', "Updates README's HELP: section"
  def help
    executable = "./bin/#{Project.instance.name}"
    unless File.exist?(executable)
      $stderr.puts "Can't update help section, executable does not exist: #{executable}"
      return
    end
    lines = (File.exist?(README))? File.readlines(README) : []
    wrote = skip = false
    File.open(README, 'w') do |io|
      while line = lines.shift
        skip = false if line=~/^##/
        next if skip
        io.puts line
        if line=~/^[=#][=#]\s*HELP:?\s*$/
          skip = true
          io.puts
          Write.help(io)
          io.puts
          wrote = true
        end
      end
      unless wrote
        io.puts "## HELP:"
        io.puts
        Write.help(io)
        io.puts
      end
    end
  end

  def self.todo(io=STDOUT)
    `grep -n '[A-Z][A-Z]*:[^:]' */*.* */*/*.* | grep '#'`.split("\n").each do |line|
      if /(?<type>[A-Z]+):(?<msg>.+)$/=~line # This is the expected form
        next unless ['TODO','DEBUG','TBD'].include?(type)
        l = line.split(/:/,3)
        io.puts "#{type}:\t#{msg.strip}"
        io.puts "\t#{l[0]}, ##{l[1]}"
      end
    end
  end

  desc 'todo', 'Writes/Updates the todo file'
  def todo
    lines = (File.exist?(TODO))? File.readlines(TODO) : []
    wrote = skip = false
    File.open(TODO, 'w') do |io|
      while line = lines.shift
        skip = false if line=~/^==/
        next if skip
        io.puts line
        if line=~/^==\s*File\s+List\s*$/
          skip = true
          io.puts
          Write.todo(io)
          io.puts
          wrote = true
        end
      end
      unless wrote
        io.puts "== File List"
        io.puts
        Write.todo(io)
        io.puts
      end
    end
  end

  def self.add_dependencies
    strbuf = ''
    #versions, grun, gdev, lrun, ldev, rrun, rdev = Ruby.dependencies
    versions, grun, gdev, _, _, rrun, rdev = Ruby.dependencies

    # Runtime Gems...
    grun.each do |lib|
      version = versions[lib]
      strbuf += "  s.add_runtime_dependency '#{lib.gsub('/','-')}', '~> #{version.sub(/\.\d+$/,'')}', '>= #{version}'\n"
    end

    # Development Gems...
    gdev.each do |lib|
      next if grun.include?(lib) # No need to repeat gems already in runtime.
      version = versions[lib]
      strbuf += "  s.add_development_dependency '#{lib}', '~> #{version.sub(/\.\d+$/,'')}', '>= #{version}'\n"
    end

    # No need to mention standard libraries
    #lrun.each do |lib|
    #  strbuf += "  s.requirements << 'requires #{lib}'\n"
    #end

    # No need to mention standard libraries
    #ldev.each do |lib|
    #  strbuf += "  s.requirements << 'requires #{lib} in development'\n"
    #end

    rrun.each do |lib|
      version = versions[".#{lib}"]
      strbuf += "  s.requirements << '#{lib}: #{version}'\n"
    end

    rdev.each do |lib|
      next if rrun.include?(lib) # No need to repeat requirement already in runtime.
      version = versions[".#{lib}"]
      strbuf += "  s.requirements << '#{lib} in development: #{version}'\n"
    end

    return strbuf
  end

  desc "gemspec", "Writes/Updates the gemspec file"
  def gemspec
    project = Project.instance

    name = project.name
    author = project.author
    readme = project.readme
    ls_files = GIT.ls_files
    executable = ls_files.include? File.join('bin',name)

    File.open(project.gemspec, 'w') do |gemspec|
      gemspec.puts <<EOT
Gem::Specification.new do |s|

  s.name     = '#{name}'
  s.version  = '#{project.version}'

  s.homepage = 'https://github.com/#{author.downcase}/#{name}'

  s.author   = '#{author}'
  s.email    = '#{project.email}'

  s.date     = '#{project.date}'
  s.licenses = ['MIT']

  s.description = <<DESCRIPTION
#{project.description}
DESCRIPTION

  s.summary = <<SUMMARY
#{project.summary}
SUMMARY

  s.require_paths = ['lib']
  s.files = %w(
#{ls_files}
  )
#{(executable)? "  s.executables << '#{name}'" : ''}
#{Write.add_dependencies}
end
EOT
    end #File.open
  end

  def self.add_history(pkgem)
    if pkgem=~/-(\d+\.\d+\.\d+)\.gem$/
      version = $1
      File.open(HISTORY, 'a') do |hst|
        hst.puts "# #{version} / #{Time.now}"
        hst.puts `md5sum #{pkgem}`
      end
    else
      EXIT.software("Could not get version from pkgem: #{pkgem}")
    end
  end
end

# cucumber wrappers
class Cucumber < Magni
  desc 'progress', 'Quick cucumber run'
  def self.progress
    pass = true
    # TODO kinda of a waste to do
    # `thor cucumber:progress` =>
    system('cucumber -f progress') or pass = false
    # There is stuff todo when something fails.
    # Needed by class Test below.
    EXIT.dataerr "There were Cucumber errors" unless pass
    puts "All Cucumber tests passed".green
  end
  def progress
    Cucumber.progress
  end
end

# ruby wrappers
class Ruby < Magni

  def self.files
    #Find.find('.') do |fn|
    GIT.ls_files.split("\n").each do |fn|
      begin
        yield(fn) if (fn =~ /\.((rb)|(thor))$/) or
        (File.file?(fn) and File.executable?(fn) and (File.open(fn, &:gets) =~ /^#!.*\bruby/))
      rescue
        STDERR.puts "Warning: could not process #{fn}"
        STDERR.puts $!.message
      end
    end
  end

  def self.tests(pattern='.')
    pattern = Regexp.new(pattern)
    Find.find('./test') do |fn|
      yield(fn) if fn=~/\.rb$/ or fn=~/\/tc_/
    end
  end

  desc 'files', 'Lists all ruby files'
  def files
    Ruby.files{|fn| puts fn}
  end

  desc 'tests [pattern]', 'Lists all unit tests matching optional filename pattern'
  def tests(pattern='.')
    Ruby.tests(pattern){|fn| puts fn}
  end

  def self.syntax
    count = 0
    Ruby.files do |fn|
      #stdout, stderr, process = Open3.capture3("ruby -c #{fn}")
      _, stderr, process = Open3.capture3("ruby -c #{fn}")
      unless process.exitstatus == 0
        count += 1
        puts stderr.chomp.red
      end
    end
    EXIT.dataerr "There were syntax errors" unless count == 0
    puts "No syntax errors found.".green
  end
  desc 'syntax', 'Quick ruby syntax check'
  def syntax
    Ruby.syntax
  end

  def self.test(pattern='.')
    pass = true
    Ruby.tests(pattern) do |fn|
      verbose = (fn=~/\.rb$/)? ' --verbose=progress' : ''
      unless system "ruby -I ./lib #{fn} #{verbose}"
        pass = false
        system("ruby -I ./lib #{fn}") unless fn=~/manually.rb$/
      end
    end
    EXIT.dataerr "There were unit-test errors" unless pass
    puts "All unit-tests passed".green
  end
  desc 'test [pattern]', 'Runs the test files filtered by optional filename pattern'
  def test(pattern='.')
    Ruby.test(pattern)
  end
 
  def self.dependencies
    name = Project.instance.name
    versions = {}; versions['.system'] = 'linux/bash'
    grun, lrun, rrun = [], [], []
    gdev, ldev, rdev = [], [], []
    Ruby.files do |fn|
      run = (fn=~/^(lib)|(bin)/)? true : false
      File.readlines(fn).each do |line|
        case line
        when /^\s*require\s['"]([^'"]+)['"]/
          lib = $1
          unless lib =~ /^#{name}\b/
            lib, version = Gem.version(lib) # lib might translate
            versions[lib] = version unless versions.has_key?(lib)
            if versions[lib]
              if run
                grun.push(lib) unless grun.include?(lib)
              else
                gdev.push(lib) unless gdev.include?(lib)
              end
            else
              if run
                lrun.push(lib) unless lrun.include?(lib)
              else
                ldev.push(lib) unless ldev.include?(lib)
              end
            end
          end
        when /^(([^#\s*`]*((\bsystem\W*)|(`\W*)))|(#\s*`))([\w\-]+)/
          cmd = $7
          k = ".#{cmd}"
          unless versions.has_key?(k)
            if system "which '#{cmd}' > /dev/null 2>&1"
              v = `#{cmd} --version 2> /dev/null`.strip.split(/\n/).first
              v = `#{cmd} -v 2> /dev/null`.strip.split.last unless v
              v = `#{cmd} -v 2>&1`.strip.split.last unless v
              versions[k] = v
            end
          end
          cmd = 'system' unless versions[k]
          if run
            rrun.push(cmd) unless rrun.include?(cmd)
          else
            rdev.push(cmd) unless rdev.include?(cmd)
          end
        end
      end
    end
    return [versions, grun, gdev, lrun, ldev, rrun, rdev]
  end

  desc 'dependencies', 'Basically just greps for ruby require lines.'
  def dependencies
    versions, grun, gdev, lrun, ldev, rrun, rdev = Ruby.dependencies
    [[grun, '# runtime gems', false, false],
     [gdev, '# development gems', false, false],
     [lrun, '# runtime libraries', false, true],
     [ldev, '# development libraries', false, true],
     [rrun, '# runtime requirements', true, false],
     [rdev, '# development requirements', true, false],
    ].each do |libs, desc, system, join|
      puts desc.blue
      if join
        puts libs.map{|l| l}.join(', ')
      else
        libs.each do |lib|
          key = (system)? ".#{lib}" : lib
          puts "#{lib}: #{versions[key]}"
        end
      end
    end
  end
end

class General < Magni
  desc "info", "Attributes of the project"
  def info
    project = Project.instance
    project.attributes.each do |attr|
      label = "#{attr}:".ljust(16)
      puts "#{label}#{project[attr].to_s.blue}"
    end
  end

  desc 'test', 'Run all tests'
  def test
    pass = true
    project = Project.instance
    project.attributes.each do |attr|
      if project.method(attr).call().nil?
        pass = false
        STDERR.puts "#{attr} undefined".red
      end
    end
    EXIT.dataerr 'Project had missing attributes' unless pass
    Ruby.syntax
    Ruby.test if File.exist?('./test')
    Cucumber.progress if File.exist?('./features')
  end

  desc "publish version", "Pushes to git and gems"
  def publish(version)
    project = Project.instance
    current = project.version
    EXIT.usage   "Current version is #{current}, not #{version}." unless current == version
    EXIT.dataerr "Found gem files in working directory"           unless project.gems.length == 0
    tags = GIT.tag_list
    EXIT.usage "'#{version}' in git tag list" if tags.include?(version)
    test # Ensure all tests pass
    Gem.build
    Gem.push(version)
    GIT.commit_and_push(version)
  end

  desc 'update_force', 'Updates gemspec and todo inspite of git status.'
  def update_force
    invoke 'write:gemspec'
    invoke 'write:todo'
    invoke 'write:help' if File.exist? "./bin/#{Project.instance.name}"
    if GIT.status_porcelain.length == 0
      puts "Gemspec and todo where uptodate."
    else
      puts "OK, now verify the changes and update git."
    end
  end

  desc 'update', 'Updates gemspec and todo'
  def update
    EXIT.dataerr "Git status not clear" unless GIT.status_porcelain.length == 0
    update_force
  end

  desc 'sow name', 'Creates a template gem diretory in the working directory'
  def sow(gemname)
    EXIT.usage "Expected a proper gem name(=~/^[a-z]+$/)" unless //.match?(gemname)
    EXIT.couldnt "#{gemname} exists." if File.exist?(gemname)
    EXIT.couldnt "git init has problems?" unless system "git init #{gemname}"
    template = File.join(__dir__,'template')
    if File.directory?(template)
      packing_list = File.join(template, 'packing-list')
      if File.file?(packing_list)
        year = Time.now.year
        author = `git config --get user.name`.strip
        state = nil
        File.read(packing_list).lines.each do |line|
          line.strip!
          if /:$/.match? line
            state = line
          else
            from_path = File.join(template, line)
            to_path = from_path.sub(template, gemname)
            case state
            when 'Files:'
              if File.directory?(from_path)
                Find.find(from_path) do |f0|
                  if File.file?(f0)
                    f1 = f0.sub(template, gemname).gsub(/\btemplate\b/, gemname)
                    puts "#{f1.ljust(30)} <= #{f0}"
                    FileUtils.mkdir_p(File.dirname(f1))
                    FileUtils.cp f0, f1
                    system "sed -i -e 's/template/#{gemname}/g' #{f1}"
                    system "sed -i -e 's/Template/#{gemname.capitalize}/g' #{f1}"
                    system "sed -i -e 's/TEMPLATE/#{gemname.upcase}/g' #{f1}"
                  end
                end
              else
                puts "#{to_path.ljust(30)} <= #{from_path}"
                FileUtils.cp from_path, to_path
                system "sed -i -e 's/template/#{gemname}/g' #{to_path}"
                system "sed -i -e 's/Template/#{gemname.capitalize}/g' #{to_path}"
                system "sed -i -e 's/TEMPLATE/#{gemname.upcase}/g' #{to_path}"
                system "sed -i -e 's/\\byear\\b/#{year}/g' #{to_path}"
                system "sed -i -e 's/\\bauthor\\b/#{author}/g' #{to_path}"
              end
            when 'Directories:'
              puts to_path
              FileUtils.mkdir_p(to_path)
            when 'Githooks:'
              Find.find(from_path) do |f0|
                if File.file?(f0)
                  f1 = f0.sub(template, gemname).gsub(/\bgit_hooks\b/, '.git/hooks')
                  puts "#{f1.ljust(30)} <= #{f0}"
                  FileUtils.cp f0, f1
                end
              end
            else
              EXIT.dataerr "packing-list in unrecognized state."
            end
          end
        end
      end
    end
  end

  desc 'template', 'compares current workspace to template'
  long_desc <<-LONG_DESC
    Compares current workspace to template
  LONG_DESC
  option :'cp', default: nil
  option :'force', default: false, type: :boolean
  def template
    cp, force  =  options[:cp], options[:force]
    checkmark, cross  =  "\u2713", "\u2715"
    template  =  File.join(__dir__,'template')
    ok = true
    ####
    ['.ruby-version', '.config.fish', '.gitignore', '.gemignore',
     '.irbrc', 'test/tc_version', 'test/tc_readme_rocket_check'
    ].each do |f|
      case cp
      when nil
        print "#{File.basename(f)}: "
        if File.exist?(f)
          if ['.irbrc'].include? f
            puts checkmark.encode('utf-8').green
          else
            if system "colordiff --ignore-matching-lines='version =' #{template}/#{f} #{f}"
              puts checkmark.encode('utf-8').green
            else
              ok &&= false
            end
          end
        else
          puts cross.encode.red
        end
      when 'cp'
        unless File.exist? f
          puts "cp #{template}/#{f} #{f}"
          system "cp #{template}/#{f} #{f}"
          ok &&= false
        end
      when File.basename(f)
        if force or not File.exist? f
          puts "cp #{template}/#{f} #{f}"
          system "cp #{template}/#{f} #{f}"
        else
          puts "File exist!".red
        end
        return
      end
    end
    ####
    f = '.git/hooks/pre-commit'
    case cp
    when nil
      print "pre-commit: "
      if File.exist?(f)
        if system "colordiff #{template}/git_hooks/pre-commit .git/hooks/pre-commit"
          puts checkmark.encode('utf-8').green
        end
      else
        puts cross.encode.red
      end
    when 'cp'
      unless File.exist? f
        puts "cp #{template}/git_hooks/pre-commit .git/hooks/pre-commit"
        system "cp #{template}/git_hooks/pre-commit .git/hooks/pre-commit"
        ok &&= false
      end
    when 'pre-commit'
      if force or not File.exist? f
        puts "cp #{template}/git_hooks/pre-commit .git/hooks/pre-commit"
        system "cp #{template}/git_hooks/pre-commit .git/hooks/pre-commit"
      else
        puts "File exist!".red
      end
      return
    else
      puts "#{cp} did not match anything.".red
      return
    end
    puts 'OK'.green  if ok
  end
end
