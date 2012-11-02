configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  
  namespace :php do
    desc "Install the latest relase of PHP and PHP-FPM"
    task :install, roles: :app do
      run "#{sudo} add-apt-repository ppa:ondrej/php5 -y"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install php5 php5-fpm php5-mysql php5-memcache php-apc php5-gd"
    end
    after "deploy:install", "php:install"
  
    desc "Setup php and php fpm configuration for this application"
    task :setup, roles: :web do
      template "php-fpm.conf.erb", "/tmp/php_fpm_conf"
      run "#{sudo} mv /tmp/php_fpm_conf /etc/php5/fpm/php-fpm.conf"

      template "php.ini.erb", "/tmp/php_ini"
      run "#{sudo} mv /tmp/php_ini /etc/php5/fpm/php.ini"
    
      restart
    end
    after "deploy:setup", "php:setup"
  
    namespace :apc do
      desc "Disable the APC administrative panel"
      task :disable, :roles => :web, :except => { :no_release => true } do
        run "rm #{current_path}/app/apc.php"
      end

      desc "Enable the APC administrative panel"
      task :enable, :roles => :web, :except => { :no_release => true } do
        run "ln -s /usr/local/lib/php/apc.php #{current_path}/app/apc.php"
      end
    end
  
    %w[start stop restart].each do |command|
      desc "#{command} php5-fpm"
      task command, roles: :web do
        run "#{sudo} service php5-fpm #{command}"
      end
    end
    after "deploy", "php:restart"
  end
end