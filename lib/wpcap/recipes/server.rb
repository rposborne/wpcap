configuration = Capistrano::Configuration.respond_to?(:instance) ?
Capistrano::Configuration.instance(:must_exist) :
Capistrano.configuration(:must_exist)

configuration.load do
  namespace :servers do
    desc "Update Servers"
    task :update do
      run "#{sudo} apt-get update -y"
      run "#{sudo} apt-get upgrade -y"
    end
  
    desc "Restart Servers"
    task :restart do
      run "#{sudo} reboot"
    end
  
    %w[access error].each do |log|
      desc "Tail #{log} log"
      task "#{log}_log", roles: :web do
        run "tail -f #{shared_path}/logs/error.log" do |channel, stream, data|
          trap("INT") { puts 'Interupted'; exit 0; } 
          puts  # for an extra line break before the host name
          puts "#{channel[:host]}: #{data}" 
          break if stream == :err
        end
      end
    end
  
    desc "Server Enviroment"
    task :get_server_enviroment do 
      run "printenv"
    end
    
  end
end