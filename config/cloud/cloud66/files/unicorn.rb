worker_processes 2
ENV['UNICORN_ENABLE_OOBGC'] = "1"
discourse_path = File.expand_path(File.expand_path(File.dirname(__FILE__)) + "/../")

working_directory "#{ENV['RAILS_STACK_PATH']}"

listen "/tmp/web_server.sock", :backlog => 64

timeout 30

pid '/tmp/web_server.pid'

stderr_path "#{ENV['RAILS_STACK_PATH']}/log/unicorn.stderr.log"
stdout_path "#{ENV['RAILS_STACK_PATH']}/log/unicorn.stdout.log"

preload_app true
GC.respond_to?(:copy_on_write_friendly=) and
    GC.copy_on_write_friendly = true

check_client_connection false

before_fork do |server, worker|
    I18n.t(:posts)
    (ActiveRecord::Base.connection.tables - %w[schema_migrations]).each do |table|
      table.classify.constantize.first rescue nil
    end    
    Rails.application.routes.recognize_path('abc') rescue nil
    GC.start
    initialized = true


    old_pid = '/tmp/web_server.pid.oldbin'
    if File.exists?(old_pid) && server.pid != old_pid
        begin
            Process.kill("QUIT", File.read(old_pid).to_i)
        rescue Errno::ENOENT, Errno::ESRCH
            # someone else did our job for us
        end
    end

    defined?(ActiveRecord::Base) and
        ActiveRecord::Base.connection.disconnect!
        $redis.client.disconnect
end

after_fork do |server, worker|
    defined?(ActiveRecord::Base) and
        ActiveRecord::Base.establish_connection
        $redis.client.reconnect
        Rails.cache.reconnect
        MessageBus.after_fork
end
