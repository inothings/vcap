include_attribute "postgresql"
default[:health_manager][:config_file] = "health_manager.yml"
default[:health_manager][:database][:username] = node[:postgresql_node][:server_root_user]
default[:health_manager][:database][:password] = node[:postgresql_node][:server_root_password]
default[:health_manager][:local_route] = nil
