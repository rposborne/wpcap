require 'erb'
require 'yaml'
require 'wpcap'
require 'wpcap/utility'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  namespace :db do
    namespace :mysql do
      desc "Install Mysql Database Server"
      task :install_server, roles: :db do
        create_yaml
        prepare_env
        run "#{sudo}  apt-get -y update"
        run "#{sudo} echo 'mysql-server-5.5 mysql-server/root_password password #{db_priv_pass}' | #{sudo} debconf-set-selections"
        run "#{sudo} echo 'mysql-server-5.5 mysql-server/root_password_again password #{db_priv_pass}' | #{sudo} debconf-set-selections"
        run "#{sudo} apt-get -y install mysql-server"
      end
      after "deploy:install", "db:mysql:install_server"
      
      desc "Install Mysql Database Client Bindings"
      task :install_client, roles: :web do
        run "#{sudo} apt-get -y update"
        run "#{sudo} apt-get -y install mysql-client"
      end
      after "deploy:install", "db:mysql:install_client"

      desc <<-EOF
      Performs a compressed database dump. \
      WARNING: This locks your tables for the duration of the mysqldump.
      Don't run it madly!
      EOF
      task :dump, :roles => :db, :only => { :primary => true } do
      
        prepare_env
        run "mkdir -p #{backups_path}"
        filename = "db_backup.#{Time.now.utc.to_i}.sql.bz2"
        filepath = "#{backups_path}/#{filename}"
        on_rollback { run "rm #{filepath}" }
        run "mysqldump --user=#{db_username} -p --host=#{db_host} #{db_database} | bzip2 -z9 > #{filepath}" do |ch, stream, out|
          ch.send_data "#{db_password}\n" if out =~ /^Enter password:/
          puts out
        end     
      end

      desc "Restores the database from the latest compressed dump"
      task :restore_most_recent, :roles => :db, :only => { :primary => true } do
        prepare_env
        run "bzcat #{most_recent_backup} | mysql --user=#{db_username} -p --host=#{db_host} #{db_database}" do |ch, stream, out|
          ch.send_data "#{db_password}\n" if out =~ /^Enter password:/
          puts out
        end
      end
    
      desc "Restores the database from the latest downloaded compressed dump"
      task :local_restore do
        prepare_env(:development)
        run_locally "bzcat #{local_dump} | #{local_mysql_path}mysql --user=#{db_username} -p#{db_password} #{db_database}" 
        run_locally "rm #{local_dump}"
      end
    
      desc "Downloads the compressed database dump to this machine"
      task :fetch_dump, :roles => :db, :only => { :primary => true } do
        prepare_env
        run_locally "touch #{local_dump}"
        download most_recent_backup, local_dump, :via => :scp
      end
    
      desc "Uploads the compressed database dump to the remote server"
      task :push_dump, :roles => :db, :only => { :primary => true } do
        prepare_env(:development)
        run_locally "#{local_mysql_path}mysqldump --user #{db_username} --password=#{db_password} #{db_database} | bzip2 -z9 > #{local_dump}"
        run "mkdir -p #{backups_path}"
        filename = "local_upload.#{Time.now.to_f}.sql.bz2"
        filepath = "#{backups_path}/#{filename}"
        upload "#{local_dump}" , "#{filepath}"
      end
    
      desc "Push the Local DB to Remote Server"
      task :push, :roles => :db do
        prepare_env
        push_dump
        restore_most_recent
        run_locally "rm #{local_dump}"
      end
    
      desc "Pull the Remote DB to Local"
      task :pull, :roles => :db do
        prepare_env
        dump
        fetch_dump
        local_restore
      end
    
      desc "Create MySQL database and user for this stage using database.yml values"
      task :create, :roles => :db, :only => { :primary => true } do
        prepare_env
        create_db_if_missing
      end 
    
      desc "Create MySQL database and user for this stage using database.yml values on your local machine"
      task :create_local_db do
        prepare_env
        create_db_if_missing("development")
      end 
    
      desc "Load the DB enviroment from the app server"
      task :prepare_enviroment do    
        prepare_env
      end
    
      desc "Remote dbconsole" 
      task :dbconsole, :roles => :app do
        prepare_env
        server = find_servers(:roles => [:db]).first
        run_with_tty server, %W( mysql --user=#{db_username} -password#{db_password} --host=#{db_host} #{db_database} )
      end
    
      desc "Create database.yml in shared path with settings for current stage and test env"
      task :create_yaml do  
        prepare_env  
        template_path = "#{shared_path}/config/database.yml"
      
        unless db_config[rails_env]
          set :db_priv_pass, random_password(16)
          set :db_username, "#{application.split(".").first}_#{stage}"
          set :db_database, "#{application.split(".").first}_#{stage}"
          set :db_password, random_password(16)
          run "mkdir -p #{shared_path}/config"
          template "mysql.yml.erb", template_path
          server_yaml = capture "cat #{template_path}"
          server_mysql_config_yaml = YAML.load(server_yaml)
          update_db_config(server_mysql_config_yaml)
        end
      end
    
      def db_config
        @db_config ||= fetch_db_config
      end
    
      def fetch_db_config
        YAML.load(File.open("config/database.yml"))
      end
    
      # Sets database variables from remote database.yaml
      def prepare_env(rails_env = stage)
        abort "No Database Configuratons Found" if !db_config 
        
        rails_env = rails_env.to_s     
        set(:local_dump)      { "/tmp/#{application}.sql.bz2" }

        if db_config[rails_env]
          set(:db_priv_user) { db_config[rails_env]["priv_username"].nil? ?  db_config[rails_env]["username"] : db_config[rails_env]["priv_username"] }
          set(:db_priv_pass) { db_config[rails_env]["priv_password"].nil? ?  db_config[rails_env]["password"] : db_config[rails_env]["priv_password"] }
          set(:db_host) { db_config[rails_env]["host"] }
          set(:db_database) { db_config[rails_env]["database"] }
          set(:db_username) { db_config[rails_env]["username"] }
          set(:db_password) { db_config[rails_env]["password"] }
          set(:db_encoding) { db_config[rails_env]["encoding"] }
          set(:db_prefix) { db_config[rails_env]["prefix"].nil? ?  db_config["development"]["prefix"] : db_config[rails_env]["prefix"] }         
        else
          Wpcap::Utility.error "No Database Configuration for #{rails_env} Found" 
          abort
        end
      
      end
    
      def update_db_config(hash_to_save)
        database_yaml = db_config.merge(hash_to_save)
        print "Saving Database Config file to local Repo"
        File.open('config/database.yml', 'w') do |f|
          f.puts YAML::dump(database_yaml).sub("---","").split("\n").map(&:rstrip).join("\n").strip
        end
      end
    
      def most_recent_backup
        most_recent_sql = capture "cd #{backups_path}; ls -lrt | awk '{ f=$NF }; END{ print f }'"
        return "#{backups_path}/#{most_recent_sql}".strip
      end
    
      def database_exits?(environment = stage)
        exists = false
        databases = run_mysql_command("show databases;", environment)
        exists = exists || databases.include?(db_database)
        exists
      end
    
      def create_db_if_missing(environment = stage)
        unless database_exits?(environment)
          sql = <<-SQL
          CREATE DATABASE #{db_database};
          GRANT ALL PRIVILEGES ON #{db_database}.* TO #{db_username}@#{db_host} IDENTIFIED BY '#{db_password}';
          SQL
        
          run_mysql_command(sql, environment)
        else
          print "databases exists -- skipping"
        end
      end
    
      def run_mysql_command(sql, environment = stage)
        environment = environment.to_s
        prepare_env(environment)
      
        db_username = db_priv_user 
        db_password = db_priv_pass
        output = ""
        if environment == "development"
          output = run_locally "#{local_mysql_path}mysql --user=#{db_username} -p#{db_password}  --execute=\"#{sql}\"" 
        else
          run "mysql --user=#{db_username} --password --execute=\"#{sql}\"" do |channel, stream, data|
            if data =~ /^Enter password:/
              channel.send_data "#{db_password}\n" 
            end
            output += data
          end
        end
        return output
      end
      before "db:mysql:push", "db:mysql:create"
      before "db:mysql:pull", "db:mysql:create_local_db"
      after "deploy:update_code" , "db:mysql:prepare_enviroment"
      after "deploy:setup", "db:mysql:create"
      before :deploy, 'db:mysql:dump' 
    end
  end
end