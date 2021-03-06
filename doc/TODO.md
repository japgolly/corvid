# MUST
------

### Fix / Enhance Existing Functionality

### New Functionality
* Integration tests. (Like NS: new dir, Guard, Rake, Simplecov)

### Non-Functional / Under-The-Hood

### Documentation
* Write an _actual_ README.
* Create a demo.



# SHOULD
--------

### Fix / Enhance Existing Functionality
* Re-eval all the old, initial Corvid template stuff (bootstraps, etc).
* Corvid init should take a project name arg and verify that it's valid.
* Some tmp dirs not being cleaned up by tests

### New Functionality
* Provide ext point: test bootstraps
* Provide ext point: `Gemfile`
* Allow a plugin to work without need for the Corvid builtin plugin.

### Non-Functional / Under-The-Hood
* Is there a point for `environment.rb`?
* Is there a point for `CORVID_ROOT`?
* Check `APP_ROOT` reliance
* Split `corvid/rake/tasks/test.rb` into unit, spec, all.
* Check transient dependencies. Like do corvid apps really need Thor on _their_ runtime dep list?
* Make corvid:init work via `install_plugin`?

### Documentation
* Doco for potential plugin devs/users
* Doc what is and isn't needed in update() in feature installers



# COULD
-------

### Fix / Enhance Existing Functionality
* `corvid help new:test:spec` doesn't work.
* Warn if uncommitted changes before install/update. Test with a few vcs systems; at least git and svn.
* Allow `copy_file()` to deploy to a different filename (without breaking patches).
* Test non-ASCII resources.
* Should tasks be organised by content before function? i.e. `project:*, test:*, plugin:*` instead of `init:*, new:*` ![?](img/question.png)
* Handle cases where installed = n and first version of feature installer is n+1
* Test Corvid and a plugin both modifying the same file.
* `corvid new:feature NAME` should prompts if more than one existing plugin found
* Update `auto-update.yml` once at end instead of after every template generated.

### New Functionality
* Provide ext point: `Guardfile`
* Provide ext point: code coverage settings
* Allow different dir structure than default
* Have Corvid provide code analysis (complexity, duplication, etc).
* Performance tests. Maybe also have results checked in so history maintained. ![?](img/question.png)
* Plugin CLI should load plugin & feature provided tasks when installed.
* Plugin CLI should provide install tasks for uninstalled plugin features (unless disabled by flag in Feature).

### Non-Functional / Under-The-Hood
* Reduce version granularity to feature?

### Documentation

