require 'erb'
require 'yaml'
require 'wpcap'
require 'wpcap/utility'
require 'wpcap/backup'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  namespace :db do
    namespace :mysql do
      desc "Install Mysql Database Server"
      task :install_server, roles: :db do
        prepare_env
        run "#{sudo} apt-get -y update"
        run "#{sudo} echo 'mysql-server-5.5 mysql-server/root_password password #{db_priv_pass}' | #{sudo} debconf-set-selections"
        run "#{sudo} echo 'mysql-server-5.5 mysql-server/root_password_again password #{db_priv_pass}' | #{sudo} debconf-set-selections"
        run "#{sudo} apt-get -y install mysql-server"
      end
      after "deploy:install", "db:mysql:install_server"
      
      desc "Save db passwords on server in enviroment so new wpcap installs may provision local databases. "
      task :set_priv_environment, roles: :db do
        #Generate a password for the mysql install  (this will be saved in the enviroment vars of the server)
        unless remote_file_exists?("/etc/wpcap/database.yml")
          
          set :db_priv_pass, random_password(16)
          run "#{sudo} mkdir -p /etc/wpcap"
          save_yaml({"db_priv_pass" => db_priv_pass, "db_priv_user" => "root"}, "/tmp/privdb.yml")
          upload "/tmp/privdb.yml", "/etc/wpcap/database.yml"

        else 
          Wpcap::Utility.error("MYSQL Server Already Configured")
        end
      end
      before "db:mysql:install_server", "db:mysql:set_priv_environment"
      
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
        filename = "db_backup.#{Time.now.to_f}.sql.bz2"
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
        restore_dump(most_recent_backup)
      end
      
      desc "Restores the database from the latest compressed dump"
      task :restore, :roles => :db, :only => { :primary => true } do
        prepare_env
        backup_list = capture "cd #{backups_path}; ls -lrt"
        backups = Wpcap::Backup.parse( backup_list )
         
        backups.each_with_index do |backup, count|
          printf "%-5s %-20s %-10s %s\n", count + 1 , backup.type , backup.size , backup.at
        end
        Wpcap::Utility.question "Select a Backup you wish to restore (1-#{backups.size})"
        restore_index = $stdin.gets.chomp
        if restore_index
          backup_to_restore = backups[restore_index.to_i - 1 ]
          full_backup_to_restore_path = "#{backups_path}/#{backup_to_restore.name}"
          Wpcap::Utility.question "Are you sure you want to restore #{full_backup_to_restore_path} (Y/n)"
          user_confirm = $stdin.gets.chomp
          if user_confirm == "Y" or user_confirm == "y"
            restore_dump(full_backup_to_restore_path)
            Wpcap::Utility.success "Database reverted to #{backup_to_restore.at}"
          else
            Wpcap::Utility.error "Canceling Restore"
          end
          
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
        create_yaml
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
        #Create a new database enviroment unless it already exists in config.
        return if db_config[stage]
        
        template_path = "#{shared_path}/config/database.yml"
        set :db_username, "#{application.split(".").first}_#{stage}"
        set :db_database, "#{application.split(".").first}_#{stage}"
        set :db_password, random_password(16)
        set :db_prefix, db_config["development"]["prefix"]
        run "mkdir -p #{shared_path}/config"
        template "mysql.yml.erb", template_path
        server_yaml = capture "cat #{template_path}"
        server_mysql_config_yaml = YAML.load(server_yaml)
        update_db_config(server_mysql_config_yaml)
        
      end
    
      def db_config
        @db_config ||= fetch_db_config
      end
    
      def remote_config(key)
        @remote_config ||= fetch_db_config(true)

        return @remote_config[key.to_s]
      end
      
      def fetch_db_config(remote = false)
        if remote
          YAML.load( capture("cat /etc/wpcap/database.yml"))
        else
          YAML.load(File.open("config/database.yml"))
        end
      end
    
      # Sets database variables from remote database.yaml
      def prepare_env(load_stage = stage)
        
        load_stage = load_stage.to_s
        
        if !db_config 
          Wpcap::Utility.error("No Database Configuratons Found")
          abort  
        end
        
        if remote_config(:db_priv_pass).nil?
          Wpcap::Utility.error "This no privleged user for this server found in servers ssh enviroment profile (did you set it up with wpcap?)" 
          abort
        end
        
        set(:local_dump)      { "/tmp/#{application}.sql.bz2" }
        
        if db_config[load_stage]
          
          set(:db_priv_user) { remote_config(:db_priv_user).nil? ?  db_config[load_stage]["username"] : remote_config(:db_priv_user) }
          set(:db_priv_pass) { remote_config(:db_priv_pass).nil? ?  db_config[load_stage]["password"] : remote_config(:db_priv_pass) }
          set(:db_host) { db_config[load_stage]["host"] }
          set(:db_database) { db_config[load_stage]["database"] }
          set(:db_username) { db_config[load_stage]["username"] }
          set(:db_password) { db_config[load_stage]["password"] }
          set(:db_encoding) { db_config[load_stage]["encoding"] }
          set(:db_prefix) { db_config[load_stage]["prefix"] }         
          
        end
      
      end
      
      def save_yaml(hash, path)
        File.open(path, 'w') do |f|
          f.puts YAML::dump(hash).sub("---","").split("\n").map(&:rstrip).join("\n").strip
        end
      end
      
      def update_db_config(stage_config)
        print "Saving Database Config file to local Repo"
        database_yaml = db_config.merge(stage_config)
        save_yaml(database_yaml, 'config/database.yml')
      end
      
      def most_recent_backup
        most_recent_sql = capture "cd #{backups_path}; ls -lrt | awk '{ f=$NF }; END{ print f }'"
        return "#{backups_path}/#{most_recent_sql}".strip
      end
      
      def restore_dump(dump_path)
        run "bzcat #{dump_path} | mysql --user=#{db_username} -p --host=#{db_host} #{db_database}" do |ch, stream, out|
          ch.send_data "#{db_password}\n" if out =~ /^Enter password:/
          puts out
        end
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