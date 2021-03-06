require 'wpcap'
require 'wpcap/utility'

configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  extraction_terms = [ {"DB_CHARSET" => "encoding"}, {"DB_NAME" => "database"} , {"DB_USER" => "username"} ,  {"DB_PASSWORD" => "password" } , {"DB_HOST" => "host"}]

  set_default :uploads_path, "wp-content/uploads"




  namespace :db do
    desc "Alias for db:mysql:pull"
    task :pull , :roles => :db do
      db.mysql.pull
    end

    desc "Alias for db:mysql:push"
    task :push , :roles => :db do
      db.mysql.push
    end
  end

  namespace :deploy do
    desc "Setup shared application directories and permissions after initial setup"
    task :setup, :roles => :web do
      # remove Capistrano specific directories

      run "rm -Rf #{shared_path}/pids"
      run "rm -Rf #{shared_path}/system"

      # create shared directories
      run "mkdir -p #{shared_path}/uploads"
      run "mkdir -p #{shared_path}/cache"
      run "mkdir -p #{shared_path}/logs"
      run "mkdir -p #{shared_path}/config"
      run "mkdir -p #{backups_path}"

      # setup for wp total cache
      run "touch #{shared_path}/config/nginx.conf"  if  custom_nginx

      # set correct permissions
      run "chmod -R 755 #{latest_release}/app/wp-content/plugins"
      run "chmod -R 775 #{shared_path}/uploads"
      run "chmod -R 775 #{shared_path}/cache"
      run "chmod -R 755 #{latest_release}"
    end

    desc "[internal] Touches up the released code. This is called by update_code after the basic deploy finishes."
    task :finalize_update, :roles => :web, :except => { :no_release => true } do
      # remove shared directories
      run "rm -Rf #{latest_release}/app/#{uploads_path}"
      run "rm -Rf #{latest_release}/wp-content/cache"

      # Removing cruft files.
      run "rm -Rf #{latest_release}/license.txt"
      run "rm -Rf #{latest_release}/readme.html"

    end
    desc "[internal] Verify Code and repo is ready to be released"
    task :check_code, :except => { :no_release => true } do
      #make sure the user has actually set up the wordpress install
      unless  File.exists?("app/wp-config.php")
        Wpcap::Utility.error("This Wordpress Installation does not appear to have a wp-config.php file (Please create one at app/wp-config.php )")
        abort
      end
    end
    before "deploy", "deploy:check_code"
    before "deploy:setup", "deploy:check_code"
  end

  namespace :wordpress do

    desc "Links the correct settings file"
    task :symlink, :roles => :web, :except => { :no_release => true } do
      run "ln -nfs #{shared_path}/uploads #{latest_release}/app/#{uploads_path}"
      run "ln -nfs #{shared_path}/cache #{latest_release}/app/wp-content/cache"

      if  custom_nginx
        run "rm -f #{shared_path}/config/nginx.conf"
        run "ln -nfs #{shared_path}/config/nginx.conf #{latest_release}/app/nginx.conf"
      end

    end

    desc "Generate a wp-config.php based upon the app server geneated db password"
    task :create_config, :roles => :web, :except => { :no_release => true } do
      run "rm #{latest_release}/app/wp-config.php"
      wpconfig = run_locally "cat app/wp-config.php"
      stage_config = "/tmp/wp-config.#{stage}"
      db.mysql.prepare_env

      extraction_terms.each do |env|
        term =  env.keys.first
        sym = env.values.first
        wpconfig = wpconfig.gsub(/define\('#{term}', '.{1,16}'\);/, "define\('#{term}', '#{send("db_"+sym)}');")
      end

      wpconfig = wpconfig.gsub(/\$table_prefix  = '.{1,16}';/, "$table_prefix  = '#{send("db_prefix")}';")
      File.open(stage_config, 'w') {|f| f.write(wpconfig) }
      upload stage_config, "#{latest_release}/app/wp-config.php"
      run_locally "rm #{stage_config}"
    end

    desc "Sync Local Assets to Remote"
    task "assets_push", :roles => :web do
      servers = find_servers_for_task(current_task)
      servers.each do |server|
        run_locally "if [ -d app/#{uploads_path} ]; then rsync -avhru app/#{uploads_path}/* -delete -e 'ssh -p #{port}' #{user}@#{server}:#{shared_path}/uploads; fi"
      end
    end

    desc "Sync Remote Assets to Local"
    task "assets_pull", :roles => :web do
      servers = find_servers_for_task(current_task)
      servers.each do |server|
        run_locally "if [ -d app/#{uploads_path} ]; then rsync -avhru -delete -e 'ssh -p #{port}' #{user}@#{server}:#{shared_path}/uploads/*    app/#{uploads_path}; fi"
      end
    end

    desc "Extract PHP DB Env Vars"
    task :extract_local_db,  :except => { :no_release => true } do
      wpconfig = run_locally "cat app/wp-config.php"
      dev_env = {"development" => {}}
      extraction_terms.each do |env|
        term =  env.keys.first
        sym = env.values.first
        dev_env["development"][sym] = wpconfig.match(/define\('#{term}', '(.{1,16})'\);/)[1]
      end

      dev_env["development"]["prefix"] = wpconfig.match(/\$table_prefix  = '(.{1,16})';/)[1]
      db.mysql.update_db_config(dev_env)
      print dev_env
    end
    before "deploy:setup", "wordpress:extract_local_db"

    desc "Set URL in database"
    task :updatedb, :roles => :db, :except => { :no_release => true } do
      db.mysql.prepare_env

      run "mysql -u #{db_username} -p #{db_database} -e 'UPDATE #{db_prefix}options SET option_value = \"#{application_url}\" WHERE option_name = \"siteurl\" OR option_name = \"home\"'" do |ch, stream, out|
        ch.send_data "#{db_password}\n" if out =~ /^Enter password:/
        puts out
      end

      run "mysql -u #{db_username} -p #{db_database} -e 'UPDATE #{db_prefix}posts SET post_content = REPLACE(post_content, \"#{local_uri}\", \"#{application_url}\")'" do |ch, stream, out|
        ch.send_data "#{db_password}\n" if out =~ /^Enter password:/
        puts out
      end
    end
    after "db:mysql:push", "wordpress:updatedb"
    after "db:mysql:push", "wordpress:assets_push"

    desc "Set URL in local database"
    task :update_local_db, :except => { :no_release => true } do
      db.mysql.prepare_env(:development)

      run_locally "#{local_mysql_path}mysql -u #{db_username} -p#{db_password} #{db_database} -e 'UPDATE #{db_prefix}options SET option_value = \"#{local_uri}\" WHERE option_name = \"siteurl\" OR option_name = \"home\"'"
      #Update Absolute URLs for wordpress content (if content is editied locally it will not push correctly to other stages)
      run_locally "#{local_mysql_path}mysql -u #{db_username} -p#{db_password} #{db_database} -e 'UPDATE #{db_prefix}posts SET post_content = REPLACE(post_content, \"#{application_url}\", \"#{local_uri}\")'"
    end

    after "db:mysql:pull", "wordpress:update_local_db"
    after "db:mysql:pull", "wordpress:assets_pull"

    desc "[internal] Protect system files"
    task :protect, :except => { :no_release => true } do
      run "chmod 444 #{latest_release}/app/wp-config.php*"
      run "cd #{current_path} && chown -R #{user} . && find . -type d -print0 | xargs -0 chmod 755"
      run "cd #{shared_path}/uploads && chown -R #{user} . && chmod 755 -R ."
    end

    desc "[internal] get current wp template from local db"
    task :current_wp_template, :except => { :no_release => true } do
      db.mysql.prepare_env(:development)
      template = run_locally "#{local_mysql_path}mysql -u #{db_username} -p#{db_password} #{db_database} -e 'SELECT `option_value` FROM `#{db_prefix}options` WHERE `option_name` = \"template\"'"
      set(:wp_template) { template.split("\n")[1]  }
      unless wp_template.length > 1
        Wpcap::Utility.error("No Wordpress Template found (Is your local Database Running?)")
        abort
      end
    end
    before "nginx:setup", "wordpress:current_wp_template"

    after "wordpress:symlink", "wordpress:create_config"
    after "wordpress:create_config", "wordpress:protect"
    after "deploy", "wordpress:symlink"
  end
end
