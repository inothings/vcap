include_attribute "deployment"

# === GATEWAY
#
#
default.elasticsearch[:gateway_index] = "0"
default.elasticsearch[:token] = "0xdeadbeef"
default.elasticsearch[:node_timeout] = 60

# === VERSION AND LOCATION
#
default.elasticsearch[:version]       = "1.7.1"
default.elasticsearch[:host]          = "http://download.elasticsearch.org"
default.elasticsearch[:repository]    = "elasticsearch/elasticsearch"
default.elasticsearch[:filename]      = "elasticsearch-#{node.elasticsearch[:version]}.tar.gz"
default.elasticsearch[:download_url]  = [node.elasticsearch[:host], node.elasticsearch[:repository], node.elasticsearch[:filename]].join('/')

# === others
default.elasticsearch[:install_path] = File.join(node[:deployment][:home], "deploy", "elasticsearch")
default.elasticsearch[:exec_path] = File.join(node.elasticsearch[:install_path], node.elasticsearch[:version])
default.elasticsearch[:logs_dir]  = node[:deployment][:log_path]
default.elasticsearch[:master_data_dir]  = '/home/ubuntu/intalio/elasticsearch'
default.elasticsearch[:capacity] = 10
default.elasticsearch[:max_memory] = 256
default.elasticsearch[:limits][:memlock] = 'unlimited'
default.elasticsearch[:limits][:nofile]  = '64000'
default.elasticsearch[:db_hostname] = node[:deployment][:db_hostname]
  
# ==== INDEX 
default.elasticsearch[:index][:number_of_shards] = 1

# === CLUSTER
#
# default.elasticsearch[:cluster][:name] = UUIDTools::UUID.random_create.to_s

# === LIMITS
#
# By default, the `mlockall` is set to true: on weak machines and Vagrant boxes,
# you may want to disable it.
#
default.elasticsearch[:bootstrap][:mlockall] = ( node.memory.total.to_i >= 1048576 ? true : false )

# === DISCOVERY
#
default.elasticsearch[:discovery][:zen][:ping][:multicast][:enabled] = true
default.elasticsearch[:discovery][:zen][:minimum_master_nodes] = 1

# === GATEWAY
#
default.elasticsearch[:gateway][:type] = 'local'
default.elasticsearch[:gateway][:expected_nodes] = 2
  
# === LOGGING
#
default.elasticsearch[:logging][:file][:max_backup_index] = 10
default.elasticsearch[:logging][:file][:max_file_size] = '10MB'
