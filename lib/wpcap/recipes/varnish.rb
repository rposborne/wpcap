configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  namespace :varnish do
    desc "Install the latest release of Varnish"
    task :install, roles: :app do
    
      run "#{sudo} curl http://repo.varnish-cache.org/debian/GPG-key.txt | sudo apt-key add -"
      run "#{sudo} echo 'deb http://repo.varnish-cache.org/ubuntu/ lucid varnish-3.0' | sudo tee -a /etc/apt/sources.list"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install varnish"
    end
    after "deploy:install", "varnish:install"
  end
end