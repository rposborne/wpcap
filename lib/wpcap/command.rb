class Wpcap::Command
  require 'shellwords'
  require 'wpcap/utility'
  
  def self.run(command, args)
    Wpcap::Command.send(command, args)
  end
  
  def self.create(args)
    @application = args.first
    @wp_root =  File.join( (args[1].nil? ? Dir.pwd : args[1]) , @application.to_s)
    locale  = args[2].nil? ? "en_US" : args[2]
    puts @wp_root
     if File.directory? "#{@wp_root}"
       puts "Project Folder Already Exists"
       return
     end
    `mkdir -p #{@wp_root}`
    `cd #{@wp_root} &&  mkdir app`

    if File.exists? @wp_root + 'app/wp-load.php'
      puts "This folder seems to already contain wordpress files. "
      return
    end

    if locale != "en_US"
      output = IO.popen( "cd #{@wp_root} && curl -s #{Shellwords.escape( 'https://api.wordpress.org/core/version-check/1.5/?locale=')}#{locale} "  )
      download_url = output[2].gsub(".zip", ".tar.gz")
      puts  'Downloading WordPress #{output[3]} (#{output[4]})...'
    else
      download_url = 'https://wordpress.org/latest.tar.gz';
      puts 'Downloading latest WordPress (en_US)...'
    end

    `cd #{@application} && curl -f #{Shellwords.escape( download_url )} | tar xz`
    `cd #{@application} && mv wordpress/* app`
    `rm -rf #{@wp_root}/wordpress`

    puts 'WordPress downloaded.'  
    self.setup
  end
  
  def self.setup
    puts "Capifying your project and seting up config directories"
    unless File.exists? "#{@wp_root}/app/wp-load.php"
      puts "This does not Appear to be a wpcap"
      return 
    end
    
    `capify #{@wp_root}`
    `touch #{@wp_root}/config/database.yml`
    `rm #{@wp_root}/config/deploy.rb`
    `cp #{File.dirname(__FILE__)}/recipes/templates/deploy.rb.erb #{@wp_root}/config/deploy.rb`
    `mkdir -p #{@wp_root}/config/deploy`
    `cp #{File.dirname(__FILE__)}/recipes/templates/deploy-stage.rb.erb  #{@wp_root}/config/deploy/staging.rb`
    `cp #{File.dirname(__FILE__)}/recipes/templates/deploy-stage.rb.erb  #{@wp_root}/config/deploy/production.rb`
    
  end
  
  def self.help(cmd)
    puts "`#{cmd}` is not a wpcap command."
    puts "See `wpcap help` for a list of available commands."
  end
end