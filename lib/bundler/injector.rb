module Bundler
  class Injector
    def self.inject(new_deps)
      injector = new(new_deps)
      injector.inject(Bundler.default_gemfile, Bundler.default_lockfile)
    end

    def initialize(new_deps)
      @new_deps = new_deps
    end

    def inject(gemfile_path, lockfile_path)
      # evaluate the Gemfile we have now
      builder = Dsl.new
      builder.eval_gemfile(gemfile_path)

      # don't inject any gems that are already in the Gemfile
      @new_deps -= builder.dependencies

      # add new deps to the end of the in-memory Gemfile
      builder.eval_gemfile("injected gems", new_gem_lines) if @new_deps.any?

      # resolve to see if the new deps broke anything
      definition = builder.to_definition(lockfile_path, {})
      definition.resolve_remotely!

      # since nothing broke, we can add those gems to the gemfile
      append_to(gemfile_path) if @new_deps.any?

      # since we resolved successfully, write out the lockfile
      definition.lock(Bundler.default_lockfile)

      # return an array of the deps that we added
      return @new_deps
    end

  private

    def new_gem_lines
      @new_deps.map do |d|
        %|gem '#{d.name}', '#{d.requirement}'|
      end.join("\n")
    end

    def append_to(gemfile_path)
      gemfile_path.open("a") do |f|
        f.puts
        f.puts "# Added at #{Time.now} by #{`whoami`.chomp}:"
        f.puts new_gem_lines
      end
    end


  end
end