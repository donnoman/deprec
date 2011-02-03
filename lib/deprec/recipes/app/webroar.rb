# Copyright 2009 by Donovan Bray. Released under the MIT license
Capistrano::Configuration.instance(:must_exist).load do
  namespace :deprec do
    namespace :webroar do

      set :webroar_log_dir, '/var/log/webroar'
      set :webroar_port, '3000'
      set(:webroar_admin_username) { Capistrano::CLI.password_prompt "Enter admin username for WebROaR:"}
      set(:webroar_admin_password) { Capistrano::CLI.password_prompt "Enter admin password for WebROaR '#{webroar_admin_username}' (minimum 6 characters):"}
      set :webroar_import_configuration, true #on re-install (true) Import settings from last install, or (false) begin fresh
      set :webroar_ssl_support, false

      SRC_PACKAGES[:webroar] = {
        :url => "git://github.com/webroar/webroar.git",
        :download_method => :git,
        :version => 'v0.2.4', # Specify a tagged release to deploy
        :configure => '',
        :make => '',
        :install => '',
        :post_install => ''
      }

      desc "Install example"
      task :install, :roles => :app do
        #indications are that webroar will not work with ree and someone said --enable-shared slows the ree interpreter down 20%, unsure of affect on mri.
        #I confirmed that as of 12/6/2009 you can't get to the admin panel of webroar when using ree.
        raise Capistrano::Error "Webroar is known to be incompatable with Ruby VM #{ruby_vm_type}" if [:ree,:none].include?(ruby_vm_type)
        SRC_PACKAGES[:webroar][:install] +=  ' ssl=on' if webroar_ssl_support
        install_deps
        deprec2.download_src(SRC_PACKAGES[:webroar], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:webroar], src_dir)
        
        run "cd /usr/local/src/webroar.git; #{sudo} rake install #{'ssl=on' if webroar_ssl_support}", :pty=>true do |ch, stream, out|
          next if out.chomp == ''
          logger.important out, ch[:server]
          case out
          when / least/
            raise Capistrano::Error, out
          when />/
            ch.send_data("#{webroar_import_configuration ? '1' : '2'}\n")
          when / username/
            ch.send_data("#{webroar_admin_username}\n")
          when / password/
            ch.send_data("#{webroar_admin_password}\n")
          when / port/
            ch.send_data("#{webroar_port}\n")
          end
        end
      end

      task :install_deps do
        apt.install( {:base => %w(build-essential zlib1g-dev libgnutls-dev libsqlite3-dev libsqlite3-ruby libopenssl-ruby)}, :stable )
        run "#{sudo} gem sources -a http://gems.github.com"
        gem2.install 'rails', '2.3.2'
        gem2.install 'calendar_date_select'
        gem2.install 'rack'
        gem2.install 'rake'
        gem2.install 'rspec'
        gem2.install 'sqlite3-ruby'
        gem2.install 'starling-starling'
      end

      SYSTEM_CONFIG_FILES[:webroar] = [

#        {:template => 'monit.conf.erb',
#         :path => "/etc/monit.d/monit_webroar.conf",
#         :mode => 0600,
#         :owner => 'root:root'}

      ]

      PROJECT_CONFIG_FILES[:webroar] = []


      desc "Generate configuration file(s) for XXX from template(s)"
      task :config_gen do
        config_gen_system
        config_gen_project
      end

      task :config_gen_system do
        SYSTEM_CONFIG_FILES[:webroar].each do |file|
          deprec2.render_template(:webroar, file)
        end
      end

      task :config_gen_project do
        PROJECT_CONFIG_FILES[:webroar].each do |file|
          deprec2.render_template(:webroar, file)
        end
      end

      desc 'Deploy configuration files(s) for XXX'
      task :config, :roles => :app do
        config_system
        config_project
      end

      task :config_system, :roles => :app do
        deprec2.push_configs(:webroar, SYSTEM_CONFIG_FILES[:webroar])
      end

      task :config_project, :roles => :app do
        deprec2.push_configs(:webroar, PROJECT_CONFIG_FILES[:webroar])
      end

      namespace :server do
        on :start, :only => "deploy:setup" do
          #During deploy:setup the application is not valid, and the server is what needs to be started.
          namespace :deprec do
            namespace :webroar do
              task :start, :roles => :app do
                top.deprec.webroar.server.start
              end
              task :restart, :roles => :app do
                top.deprec.webroar.server.restart
              end
            end
          end
        end
        %w(start stop restart reload).each do |name|
          task name.to_sym, :roles => :app do
            run "#{sudo} /etc/init.d/webroar #{name}"
          end
        end

      end

      after "deploy:restart", "deprec:webroar:restart"
      
      %w(start stop restart reload).each do |name|
        task name.to_sym, :roles => :app do
          run "#{sudo} webroar #{name} #{application}; exit 0"  #Manual Configuration required, this is best effort.
        end
      end

      task :reload, :roles => :app do
        run "#{sudo} webroar restart #{application}; exit 0"
      end

      task :activate, :roles => :app do
      end

      task :deactivate, :roles => :app do
      end

      task :backup, :roles => :app do
      end

      task :restore, :roles => :app do
      end

      task :tail, :roles => :app do
        stream "tail -f #{webroar_log_dir}/*.log"
      end

    end
  end
end

