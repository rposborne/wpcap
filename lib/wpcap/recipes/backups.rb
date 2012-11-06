configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  namespace :backups do
    
    #Hooks
    before :deploy, 'db:mysql:dump' 
    
  
    #Taks
    desc "List all available backups"
    task :default, :except => { :no_release => true } do
      db.mysql.restore
    end
    
    desc <<-DESC
    Clean up old releases. By default, the last 5 backups are kept on each \
    server (though you can change this with the keep_releases variable). All \
    other deployed revisions are removed from the servers. By default, this \
    will use sudo to clean up the old releases, but if sudo is not available \
    for your environment, set the :use_sudo variable to false instead.
    DESC
    task :cleanup, :except => { :no_release => true } do
      count = fetch(:keep_backups, 5).to_i
      local_backups = capture("ls -xt #{backups_path}").split.reverse
      if count >= local_backups.length
        logger.important "no old backups to clean up"
      else
        logger.info "keeping #{count} of #{local_backups.length} backups"
        directories = (local_backups - local_backups.last(count)).map { |release|
          File.join(backups_path, release) }.join(" ")

          try_sudo "rm -rf #{directories}"
        end
      end
  end
end

