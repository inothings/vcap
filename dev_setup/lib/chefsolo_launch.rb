#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'tempfile'
require 'uri'
require 'fileutils'
require 'optparse'
require 'yaml'
require 'pp'

$LOAD_PATH.unshift(File.dirname(__FILE__))

require File.expand_path('vcap_defs', File.dirname(__FILE__))
require File.expand_path('job_manager', File.dirname(__FILE__))

script_dir = File.expand_path(File.dirname(__FILE__))
cloudfoundry_home = Deployment.get_cloudfoundry_home
deployment_spec = File.expand_path(File.join(script_dir, "..", DEPLOYMENT_DEFAULT_SPEC))

args = ARGV.dup
opts_parser = OptionParser.new do |opts|
  opts.on('--config CONFIG_FILE', '-c CONFIG_FILE') { |file| deployment_spec = File.expand_path(file.to_s) }
  opts.on('--dir CLOUDFOUNDRY_HOME', '-d CLOUDFOUNDRY_HOME') { |dir| cloudfoundry_home = File.expand_path(dir.to_s) }
end
args = opts_parser.parse!(args)

unless File.exists?(deployment_spec)
  puts "Cannot find config file #{deployment_spec}"
  puts "Usage: #{$0} -c config_file -d cloud_foundry_home"
  exit 1
end

spec = YAML.load_file(deployment_spec)

# Fill in default config attributes
spec["deployment"] ||= {}
spec["deployment"]["name"] ||= DEPLOYMENT_DEFAULT_NAME
spec["deployment"]["user"] ||= ENV["USER"]
spec["deployment"]["group"] ||= `id -g`.strip
spec["cloudfoundry"] ||= {}
spec["cloudfoundry"]["home"] ||= cloudfoundry_home
spec["cloudfoundry"]["home"] = File.expand_path(spec["cloudfoundry"]["home"])

if cloudfoundry_home != Deployment.get_cloudfoundry_home && cloudfoundry_home != spec["cloudfoundry"]["home"]
  puts "Conflicting values for cloudfoundry home directory, command line argument says #{cloudfoundry_home} but config file says #{spec["cloudfoundry"]["home"]}"
  exit 1
end

# convenience variables
cloudfoundry_home = spec["cloudfoundry"]["home"]
deployment_name = spec["deployment"]["name"]
deployment_config_path = Deployment.get_config_path(deployment_name, cloudfoundry_home)

puts "Installing deployment #{deployment_name}, cloudfoundry home dir is #{cloudfoundry_home}"

# Resolve all job dependencies
vcap_run_list = {}
job_specs, job_roles, vcap_run_list["components"] = JobManager.go(spec)
if job_roles.nil?
  puts "You haven't specified any install jobs"
  exit 0
end

# Prepare the chef run list
run_list = []
job_roles.each do |role|
  run_list << "role[#{role}]"
end
spec["run_list"] = run_list

# Merge the job specs
spec.merge!(job_specs)

# Deploy
Dir.mktmpdir do |tmpdir|
  # Create chef-solo config file
  File.open(File.join(tmpdir, "solo.rb"), "w") do |f|
    f.puts("cookbook_path \"#{File.expand_path(File.join("..", "cookbooks"), script_dir)}\"")
    f.puts("role_path \"#{File.expand_path(File.join("..", "roles"), script_dir)}\"")

    %w[ http_proxy https_proxy].each do |proxy|
      if ENV[proxy]
        uri = URI.parse(ENV[proxy])
        f.puts("#{proxy} \"#{uri.scheme}://#{uri.host}:#{uri.port}\"")
        if uri.userinfo
          f.puts("http_proxy_user \"#{uri.userinfo.split(":")[0]}\"")
          f.puts("http_proxy_pass \"#{uri.userinfo.split(":")[1]}\"")
        end
      end
    end
    if ENV["no_proxy"]
      f.puts("no_proxy \"#{ENV["no_proxy"]}\"")
    end
  end

  # Create chef-solo attributes file
  json_attribs = File.join(tmpdir, "solo.json")
  File.open(json_attribs, "w") { |f| f.puts(spec.to_json) }

  # Save the chef-solo attributes to a file in /tmp, useful for debugging
  File.open(File.join("", "tmp", "solo.json"), "w") { |f| f.puts(spec.to_json) }

  id = fork do
    proxy_env = []
    # Setup proxy
    %w(http_proxy https_proxy no_proxy).each do |env_var|
      if ENV[env_var] || ENV[env_var.upcase]
        [env_var, env_var.upcase].each do |v|
          proxy = "#{v}=#{ENV[v.downcase] || ENV[v.upcase]}"
          proxy_env << proxy
        end
      end
    end
    exec("sudo env #{proxy_env.join(" ")} chef-solo -c #{File.join(tmpdir, "solo.rb")} -j #{json_attribs} -l debug")
  end

  pid, status = Process.waitpid2(id)
  if status.exitstatus != 0
    exit status.exitstatus
  end

  # save the config of this deployment
  File.open(Deployment.get_config_file(deployment_config_path), "w") { |f| f.puts(spec.to_json) }

  # save the list of components that should be started for this deployment
  File.open(Deployment.get_vcap_config_file(deployment_config_path), "w") { |f| f.puts(vcap_run_list.to_json) }

  # save the deployment target for later use
  Deployment.save_deployment_target(deployment_name, cloudfoundry_home)

  puts "---------------"
  puts "Deployment info"
  puts "---------------"
  puts "Status: successful"

  vcap_dev_path = File.expand_path(File.join(script_dir, "..", "bin", "vcap_dev"))
  vcap_dev_update_ip_path = File.expand_path(File.join(script_dir, "..", "bin", "vcap_dev_update_ip"))
  deployment_path = File.expand_path(File.join(cloudfoundry_home, '.deployments', deployment_name)) #TODO: clean this.
  puts "Config files: #{deployment_config_path}"
  puts "Deployment name: #{deployment_name}"
  puts "NOTE: If you want to run ruby/vmc please source the profile #{Deployment.get_deployment_profile_file}"
  args = ""
  args << (deployment_name != DEPLOYMENT_DEFAULT_NAME ? " -n #{deployment_name}" : "")
  args << (cloudfoundry_home != Deployment.get_cloudfoundry_home ? " -d #{cloudfoundry_home}" : "")
  args << " start"
  puts "Command to run cloudfoundry: #{vcap_dev_path} #{args.strip}"
  puts "Or: #{cloudfoundry_home}/_vcap #{args.strip}"
  
  Dir.chdir cloudfoundry_home do
    
    File.open("_#{deployment_name}", 'w') do |f|  
      f.puts "#!/bin/bash"
      f.puts "#Make sure HOME and USER are set: with monit as a daemon it is not set."
      f.puts "[ -z \"$HOME\"] && export HOME=#{ENV['HOME']}"
      f.puts "[ -z \"$USER\"] && export HOME=#{ENV['USER']}"
      f.puts "_vcap_log=#{deployment_path}/log/_vcap.log"
      f.puts "echo \"_vcap called with $@\" | tee -a $_vcap_log"
      f.puts "#{vcap_dev_update_ip_path} #{deployment_path}/config | tee -a $_vcap_log"
      f.puts "[ \"$1\" = \"update-ip\" ] && exit 0"
      f.puts "#{vcap_dev_path} --name #{deployment_name} --dir #{cloudfoundry_home} $@  | tee -a $_vcap_log"
    end
    
    `chmod +x _vcap`
  
    # few symbolic links (todo: too many assumptions on the layout of the deployment)
    `[ -h log ] && rm log`
    `ln -s #{deployment_path}/log log`
    `[ -h config ] && rm config`
    `ln -s #{deployment_path}/config config`
    `[ -h deployed_apps ] && rm deployed_apps`
    `ln -s /var/vcap.local/dea/apps deployed_apps`
    
  end
  
end
