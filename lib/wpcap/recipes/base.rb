require 'rubygems'
require 'railsless-deploy'
require 'capistrano/ext/multistage'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  
  def template(from, to)
    erb = File.read(File.expand_path("../templates/#{from}", __FILE__))
    put ERB.new(erb).result(binding), to
  end

  def set_default(name, *args, &block)
    set(name, *args, &block) unless exists?(name)
  end

  def random_password(size = 8)
    chars = (('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
    (1..size).collect{|a| chars[rand(chars.size)] }.join
  end

  def run_with_tty(server, cmd)
    # looks like total pizdets
    command = []
    command += %W( ssh -t #{gateway} -l #{self[:gateway_user] || self[:user]} ) if     self[:gateway]
    command += %W( ssh -t )
    command += %W( -p #{server.port}) if server.port
    command += %W( -l #{user} #{server.host} )
    command += %W( cd #{current_path} )
    # have to escape this once if running via double ssh
    command += [self[:gateway] ? '\&\&' : '&&']
    command += Array(cmd)
    system * command
  end

  default_run_options[:pty] = true
  ssh_options[:forward_agent] = true
  set :use_sudo , false
 
  namespace :deploy do
    desc "Install everything onto the server"
    task :install do
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install git debconf-utils python-software-properties"
    end
  end
  
  desc "Tail all or a single remote file"
  task :tail do
    ENV["LOGFILE"] ||= "*.log"
    run "tail -f #{shared_path}/logs/#{ENV["LOGFILE"]}" do |channel, stream, data|
      puts "#{data}"
      break if stream == :err
    end
  end
end