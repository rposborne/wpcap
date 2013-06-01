configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  namespace :nginx do
    desc "Install latest stable release of nginx"
    task :install, roles: :web do
      run "#{sudo} add-apt-repository ppa:nginx/stable -y"
      run "#{sudo} apt-get -y update"
      run "#{sudo} apt-get -y install nginx"
    end
    after "deploy:install", "nginx:install"

    desc "Setup nginx configuration for this application"
    task :setup, roles: :web do
      template "nginx_php.erb", "/tmp/nginx_conf"
      run "#{sudo} mv /tmp/nginx_conf /etc/nginx/sites-enabled/#{application}"
      run "#{sudo} rm -f /etc/nginx/sites-enabled/default"
      run "mkdir -p #{shared_path}/logs"
      run "#{sudo} touch #{shared_path}/logs/access.log"
      run "#{sudo} touch #{shared_path}/logs/error.log"
    end
    after "deploy:setup", "nginx:setup"
    after "deploy:setup", "nginx:restart"
    %w[start stop restart].each do |command|
      desc "#{command} nginx"
      task command, roles: :web do
        run "#{sudo} service nginx #{command}"
      end
    end
  end
end
