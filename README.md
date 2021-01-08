# martelo

* [VERSION 8.21.210108](https://github.com/carlosjhr64/martelo/releases)
* [github](https://www.github.com/carlosjhr64/martelo)

## DESCRIPTION:

My personal `tasks.thor` file.

Worth repeating...
Again, this is my personal `tasks.thor` file.
Having said that, maybe others will find it useful.

## THOR LIST:

    $ cucumber
    $ --------
    $ thor cucumber:progress  # Quick cucumber run

    $ gem
    $ ---
    $ thor gem:build  # Builds gem from gemspec

    $ general
    $ -------
    $ thor general:info             # Attributes of the project
    $ thor general:publish version  # Pushes to git and gems
    $ thor general:sow name         # Creates a template gem directory in the working directory
    $ thor general:template         # compares current workspace to template
    $ thor general:test             # Run all tests
    $ thor general:update           # Updates gemspec and todo

    $ git
    $ ---
    $ thor git:commit_and_push "tag"  # git commit and push with tag

    $ ruby
    $ ----
    $ thor ruby:dependencies     # Basically just greps for ruby require lines.
    $ thor ruby:files            # Lists all ruby files
    $ thor ruby:syntax           # Quick ruby syntax check
    $ thor ruby:test [pattern]   # Runs the test files filtered by optional filename pattern
    $ thor ruby:tests [pattern]  # Lists all unit tests matching optional filename pattern

    $ tasks
    $ -----
    $ thor tasks:commit  # commits tasks.thor's edits
    $ thor tasks:diff    # tasks.thor's `git diff`
    $ thor tasks:edit    # Edit tasks.thor
    $ thor tasks:revert  # reverts to tasks.thor's last commit

    $ write
    $ -----
    $ thor write:gemspec  # Writes/Updates the gemspec file
    $ thor write:help     # Updates README's HELP: section
    $ thor write:todo     # Writes/Updates the todo file

## INSTALL:

Typically you would have a gits directory where you keep your projects, and
your tasks.thor file would be found there.
These instructions do not allow for merging with existing tasks... sorry.
But this is how I have things set up:

    $ /path-to-gits/martelo/
    $ /path-to-gits/tasks.thor -> ./martelo/lib/martelo.rb
    $ /path-to-gits/template/

So, do this:

    $ cd /path-to-gits/
    $ git clone git@github.com:carlosjhr64/martelo.git
    $ git clone git@github.com:carlosjhr64/template.git
    $ ln -s ./martelo/lib/martelo.rb tasks.thor

The template git has my personal projects template.
Next you'll need to ensure some require gems, and
obviously you should have ruby:

    $ gem install thor # well... duh!
    $ gem install helpema
    $ gem install colorize

In any case, you'll know of any other missing gems because you'll get an error saying so.
I should also note that I use rbenv, but I don't think it's required.
So if everything works, you should be able to start a new project:

    # Create a new project in /path-to-git/new_project/
    $ cd /path-to-git
    $ thor general:sow new_project

## LICENSE:

Copyright 2021 carlosjhr64

Permission is hereby granted, free of charge,
to any person obtaining a copy of this software and
associated documentation files (the "Software"),
to deal in the Software without restriction,
including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and
to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice
shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS",
WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH
THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
