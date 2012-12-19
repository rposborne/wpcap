module Wpcap
  class Command
    require 'shellwords'
    require 'wpcap/utility'
    require 'net/http'

    def self.run(command, args)
      Wpcap::Command.send(command, args)
    end

    def self.create(args)
      @application = args.first.to_s.downcase
      @wp_root = File.join( (args[1].nil? ? Dir.pwd : args[1]) , @application)
      @app_dir = @wp_root + "/app"

      if File.directory? "#{@wp_root}"
        warn "Project Folder Already Exists"
        abort
      end

      FileUtils.mkdir_p(@wp_root)

      install_wordpress @app_dir

      self.setup
    end

    def self.build(args)
      @wp_root = File.expand_path args.first
      @application = File.dirname @wp_root
      puts "Processing #{@wp_root} into a wpcap directory style"
      unless File.exists? @wp_root + '/wp-load.php'
        warn "This folder does not appear to be a wordpress directory. "
        abort
      end

      FileUtils.mv @wp_root, @wp_root + "/app", :force => true
      self.setup
    end

    def self.setup
      puts "Capifying your project and seting up config directories"
      unless File.exists? "#{@app_dir}/wp-load.php"
        warn "This does not Appear to be a wpcap project"
        abort
      end

      self.capify(@wp_root)

      FileUtils.mkdir_p "#{@wp_root}/config/deploy"
      FileUtils.touch "#{@wp_root}/config/database.yml"
      FileUtils.rm "#{@wp_root}/config/deploy.rb" if File.exists?  "#{@wp_root}/config/deploy.rb"
      FileUtils.cp "#{File.dirname(__FILE__)}/recipes/templates/deploy.rb.erb"      ,   "#{@wp_root}/config/deploy.rb"
      FileUtils.cp "#{File.dirname(__FILE__)}/recipes/templates/deploy_stage.rb.erb",   "#{@wp_root}/config/deploy/staging.rb"
      FileUtils.cp "#{File.dirname(__FILE__)}/recipes/templates/deploy_stage.rb.erb",   "#{@wp_root}/config/deploy/production.rb"

      puts "You are all Done, begin building your wordpress site in the app directory!"
    end

    def self.help(cmd)
      puts "`#{cmd}` is not a wpcap command."
      puts "See `wpcap help` for a list of available commands."
    end

    private

    def self.install_wordpress(path)
      unless Dir.exists?("/tmp/wordpress")
        puts 'Downloading latest WordPress (en_US)...'
        Net::HTTP.start("wordpress.org") do |http|
          resp = http.get("/latest.tar.gz")
          open("/tmp/latest.tar.gz", "wb") do |file|
            file.write(resp.body)
          end
        end
        `tar -zxf /tmp/latest.tar.gz`
        puts 'WordPress downloaded and extracted.'
      end

      FileUtils.mv "/tmp/wordpress/", "#{path}", :force => true

    end

    def self.capify(path)

      ARGV[0] = @wp_root
      version = ">= 0"

      gem 'capistrano', version
      load Gem.bin_path('capistrano', 'capify', version)
    end
  end
end
