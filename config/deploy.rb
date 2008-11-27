# This is a sample Capistrano config file for EC2 on Rails.
# It should be edited and customized.
require 'capistrano/version'
load 'deploy' if respond_to?(:namespace) # cap2 differentiator

# EC2 on Rails config.
# NOTE: Some of these should be omitted if not needed.
set :ec2onrails_config, {
  # S3 bucket and "subdir" used by the ec2onrails:db:restore task
  # NOTE: this only applies if you are not using EBS
  :restore_from_bucket => "adiserver",
  :restore_from_bucket_subdir => "database",
  
  # S3 bucket and "subdir" used by the ec2onrails:db:archive task
  # This does not affect the automatic backup of your MySQL db to S3, it's
  # just for manually archiving a db snapshot to a different bucket if
  # desired.
  # NOTE: this only applies if you are not using EBS
  :archive_to_bucket => "adiserver",
  :archive_to_bucket_subdir => "db-archive/#{Time.new.strftime('%Y-%m-%d--%H-%M-%S')}",
  
  # Set a root password for MySQL. Run "cap ec2onrails:db:set_root_password"
  # to enable this. This is optional, and after doing this the
  # ec2onrails:db:drop task won't work, but be aware that MySQL accepts
  # connections on the public network interface (you should block the MySQL
  # port with the firewall anyway).
  # If you don't care about setting the mysql root password then remove this.
  :mysql_root_password => "standforus",
  
  # Any extra Ubuntu packages to install if desired
  # If you don't want to install extra packages then remove this.
  :packages => ["logwatch", "libmagick9-dev", "imagemagick", "emacs", "xfsprogs"],
  
  # Any extra RubyGems to install if desired: can be "gemname" or if a
  # particular version is desired "gemname -v 1.0.1"
  # If you don't want to install extra rubygems then remove this
  #:rubygems => [],
  
  # Defines the web proxy that will be used. Choices are :apache or :nginx
  :web_proxy_server => :nginx,
  
  # extra security measures are taken if this is true, BUT it makes initial
  # experimentation and setup a bit tricky. For example, if you do not
  # have your ssh keys setup correctly, you will be locked out of your
  # server after 3 attempts for upto 3 months.
  :harden_server => false,
  
  # Set the server timezone. run "cap -e ec2onrails:server:set_timezone" for
  # details
  :timezone => "UTC",
  
  # Files to deploy to the server (they'll be owned by root). It's intended
  # mainly for customized config files for new packages installed via the
  # ec2onrails:server:install_packages task. Subdirectories and files inside
  # here will be placed in the same structure relative to the root of the
  # server's filesystem.
  # If you don't need to deploy customized config files to the server then
  # remove this.
  #:server_config_files_root => "../server_config",
  
  # If config files are deployed, some services might need to be restarted.
  # If you don't need to deploy customized config files to the server then
  # remove this.
  :services_to_restart => %w(postfix sysklogd),
  
  # Set an email address to forward admin mail messages to. If you don't
  # want to receive mail from the server (e.g. monit alert messages) then
  # remove this.
  :mail_forward_address => "steve@sympact.net",
  
  # Set this if you want SSL to be enabled on the web server. The SSL cert
  # and key files need to exist on the server, The cert file should be in
  # /etc/ssl/certs/default.pem and the key file should be in
  # /etc/ssl/private/default.key (see :server_config_files_root).
  :enable_ssl => true
}



set :application, "adiserver"
 
set :scm, :git
default_run_options[:pty] = true
set :repository, "git@github.com:smartocci/adiserver.git"
#set :user, "root"
set :git_enable_submodules, 1
set :deploy_via, :remote_cache
#might not need this
ssh_options[:forward_agent] = true
 
# NOTE: for some reason Capistrano requires you to have both the public and
# the private key in the same folder, the public key should have the
# extension ".pub".
ssh_options[:keys] = ["#{ENV['HOME']}/.ssh/sympact"]

task :production do 
  # Your EC2 instances. Use the ec2-xxx....amazonaws.com hostname, not
  # any other name (in case you have your own DNS alias) or it won't
  # be able to resolve to the internal IP address.
  #"0.web.production.ec2.sympact.net"
  role :web, "ec2-75-101-136-136.compute-1.amazonaws.com"
  role :web, "ec2-75-101-207-196.compute-1.amazonaws.com"
  role :app, "ec2-75-101-136-136.compute-1.amazonaws.com", :data_updater => true
  role :app, "ec2-75-101-207-196.compute-1.amazonaws.com"
  role :memcache, "ec2-75-101-136-136.compute-1.amazonaws.com"
  role :memcache, "ec2-75-101-207-196.compute-1.amazonaws.com"
  #role :db, "ec2-75-101-136-136.compute-1.amazonaws.com", :primary => true
  role :db, "ec2-67-202-20-45.compute-1.amazonaws.com", :primary => true, :ebs_vol_id => 'vol-a4a743cd'
  # optinally, you can specify Amazon's EBS volume ID if the database is persisted
  # via Amazon's EBS. See the main README for more information.
 
  # Whatever you set here will be taken set as the default RAILS_ENV value
  # on the server. Your app and your hourly/daily/weekly/monthly scripts
  # will run with RAILS_ENV set to this value.
  set :rails_env, "production_ec2"
  
  # make an "admin" role for each role, and create arrays containing
  # the names of admin roles and non-admin roles for convenience
  
  roles.keys.clone.each do |name|
    make_admin_role_for(name)
    all_non_admin_role_names << name
    all_admin_role_names << "#{name.to_s}_admin".to_sym
  end

end

task :staging do
  role :web, "ec2-75-101-196-86.compute-1.amazonaws.com"
  role :app, "ec2-75-101-196-86.compute-1.amazonaws.com"
  role :memcache, "ec2-75-101-196-86.compute-1.amazonaws.com"
  role :db, "ec2-75-101-196-86.compute-1.amazonaws.com", :primary => true, :ebs_vol_id => 'vol-e6ad498f'
  
  set :rails_env, "staging_ec2"
  
  # make an "admin" role for each role, and create arrays containing
  # the names of admin roles and non-admin roles for convenience
  
  roles.keys.clone.each do |name|
    make_admin_role_for(name)
    all_non_admin_role_names << name
    all_admin_role_names << "#{name.to_s}_admin".to_sym
  end
end
 
require 'ec2onrails/recipes'
 
set :tools_path, "/mnt/tools" 
namespace :adiserver do
  namespace :ec2 do
    
    desc "sets up new box as needed"
    task :setup do
      adiserver.ec2.copy_github_keys
      adiserver.ec2.install_memcached
      adiserver.ec2.install_geoip
      adiserver.ec2.install_duplicity
      adiserver.ec2.upload_sympact_tools
      adiserver.ec2.upload_monit_scripts
    end
    
    
    desc "copy sympact tools to server"
    task :upload_sympact_tools, :roles => all_admin_role_names do
      sudo "rm -rf #{tools_path}"
      sudo "mkdir #{tools_path}"
      sudo "chown admin:admin #{tools_path}"
      upload "clients/tools/", "/mnt", :via => :scp, :recursive => true
    end
    
      
    
    
    
    desc "copy the GitHub keys"
    task :copy_github_keys , :roles => :app do
      upload "clients/config/id_rsa", "~/.ssh", :via => :scp
      upload "clients/config/id_rsa.pub", "~/.ssh", :via => :scp
    end
    
    desc "installs memcached"
    task :install_memcached, :roles => :app_admin do 
      #install libmemcached and memcached gem
      run <<-CMD 
        sudo chown admin:admin /usr/local/src;
        cd /usr/local/src;
        curl -O http://download.tangent.org/libmemcached-0.22.tar.gz;
        tar xvzf libmemcached-0.22.tar.gz;
        cd libmemcached-0.22;
        ./configure;
        make;
        sudo make install;
        sudo ln -s /usr/local/lib/libmemcached.so.2 /usr/lib/;
        sudo gem install memcached --no-rdoc --no-ri --force;
      CMD
    end
    
    task :update_apt, :roles => all_admin_role_names do 
      sudo "apt-get update"
    end
    
    
    task :upgrade_rubygems, :roles => all_admin_role_names do 
      sudo "gem install rubygems-update"
      sudo "update_rubygems"
    end

    task :install_geoip, :roles => :app_admin do
      run <<-CMD
        sudo chown admin:admin /usr/local/src;
        cd /usr/local/src;
        wget -O GeoIP-1.4.5.tar.gz http://www.maxmind.com/download/geoip/api/c/GeoIP-1.4.5.tar.gz;
        tar zxvf GeoIP-1.4.5.tar.gz;
        cd GeoIP-1.4.5;
        ./configure;
        make;
        make check;
        sudo make install;
        sudo echo /usr/local/src/GeoIP-1.4.5 > sudo /etc/ld.so.conf.d/geoip-city.conf;
        sudo ldconfig;
        sudo gem install geoip_city -- --with-geoip-dir=/usr/local/src/GeoIP-1.4.5;
      CMD
    end

    #task :install_imagemagick, :roles => :app_admin do
    #  sudo "apt-get install image-magick, libmagick9-dev"
    #end


    task :install_duplicity, :roles => :db_admin do 
      sudo "apt-get install duplicity -y"
      run <<-CMD 
        sudo chown admin:admin /usr/local/src;
        cd /usr/local/src;
        curl -O http://boto.googlecode.com/files/boto-1.4c.tar.gz;
        tar xvzf boto-1.4c.tar.gz;
        sudo ln -s /usr/local/src/boto-1.4c/boto /usr/local/lib/python2.5/site-packages;
      CMD
    end
    
    task :upload_duplicity_key, :roles => :db_admin do 
      upload "clients/config/key.txt", "~/key.txt", :via => :scp
      sudo "gpg --import /home/admin/key.txt"
    end
    
    task :upload_monit_scripts, :roles => all_admin_role_names do 
       sudo "rm -rf /mnt/tmp/ec2"
      upload "clients/monit/ec2/", "/mnt/tmp", :via => :scp, :recursive => true
      sudo "cp /mnt/tmp/ec2/* /etc/monit"
    end
    
    namespace :data_updater do
       [ :stop, :start, :restart ].each do |t|
         desc "#{t.to_s.capitalize} the Data Updater process"
         task t, :role => :data_updater, :roles => :data_updater_admin do
           sudo "monit -g data_updater_#{application}_ec2 #{t.to_s} all"
         end
       end  
     end
    
    
  end
end 
after "adiserver:ec2:install_duplicity", 'adiserver:ec2:upload_duplicity_key'
after "deploy:setup", "create_cache_dir"
before "ec2onrails:server:install_packages", "adiserver:ec2:update_apt"
before "ec2onrails:server:install_gems", "adiserver:ec2:upgrade_rubygems"
# =============================================================================
# Any custom after tasks can go here.
 after "deploy:symlink", "adiserver_custom"
 after "deploy:symlink", "app_gems"
 task :adiserver_custom, :roles => :app, :except => {:no_release => true, :no_symlink => true} do
   run <<-CMD
    ln -nfs #{shared_path}/cache #{release_path}/clients/cache;
    ln -nfs #{release_path}/clients/cache/assets #{release_path}/public/assets;
    ln -nfs #{release_path}/clients/cache/fonts #{release_path}/public/fonts;
    ln -nfs #{release_path}/clients/cache/nodes #{release_path}/public/nodes;
   CMD
 end
 
 task :create_cache_dir, :roles => :app do
   run <<-CMD
     mkdir -p #{shared_path}/cache;
     mkdir -p #{shared_path}/cache/assets;
     mkdir -p #{shared_path}/cache/fonts;
     mkdir -p #{shared_path}/cache/nodes;
   CMD
  end
  
  task :app_gems, :roles => :app_admin do 
    sudo "rake -f /mnt/app/current/Rakefile gems:install RAILS_ENV=#{rails_env}"
  end
  
  
  #task :upload_database_yml, :roles => :app do
  #  upload "config/database.yml.ec2", "#{shared_path}/database.yml", :via => :scp
  #end
  
  
  
  
  
  
  task :restore_duplicity, :roles => :db_admin do
    sudo "rm -rf /tmp/db_restore"
    sudo "#{tools_path}/bin/duplicity_wrapper adiserver_production restore /tmp/db_restore"
    puts "Duplicity restored to /tmp/db_restore, now loading into mysql...."
    sudo "mysql -uroot adiserver_production < /tmp/db_restore/data/db_dump/adiserver_production.sql "
  end
  
  
  

 
   


