default[:postgresql_node][:server_root_password] = "changeme"
default[:postgresql_node][:server_root_user] = "cloudfoundry"
default[:postgresql_node][:database] = "pg_service"
default[:postgresql_node][:version] = "9.0"
default[:postgresql_node][:index] = "0"
default[:postgresql_node][:max_db_size] = "500"
default[:postgresql_node][:available_storage] = "1024"
default[:postgresql_node][:token] = "changepostgresqltoken"
default[:postgresql_node][:ltree_in_template1] = false
default[:postgresql_node][:max_long_query] = 3
default[:postgresql_node][:max_long_tx] = 30
default[:postgresql_node][:max_db_conns] = 20
default[:postgresql_node][:node_timeout] = 2 #the value hardocded here: https://github.com/cloudfoundry/vcap-services/commit/fe6415a8142f11b93e4197eb5663fd61b272eef3#L2R15
default[:postgresql_node][:listen_addresses] = "#{node[:postgresql_node][:host]},localhost"
