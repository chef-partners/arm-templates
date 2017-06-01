require 'json'
require 'pathname'
require 'open3'

class Deploy < Thor

  desc "create [URI] [PARAMETERS_PATH] [GROUP]", "Create a deployment in Azure"
  method_option :count, :type => :numeric, :default => 1
  method_option '--no-delete', :type => :boolean, :default => false
  method_option :location, :type => :string, :default => "westeurope"
  method_option :dryrun, :type => :boolean, :default => false
  method_option '--no-wait', :type => :boolean, :default => false
  def create(uri, parameters, group)

    if !(Pathname.new(parameters)).absolute?
      parameters = File.join(Dir.pwd, parameters)
    end

    # Perform some tests to check that the supplied options work
    fail "The specified path cannot be found" unless File.exists?(parameters)

    # Set an array to hold the commands that need to be executed
    cmds = []

    # Read the configuration file for this task to determine the group to delete and
    # the one to create
    configuration_file = File.join(File.dirname(__FILE__), '../..', '.thor/deploy.json')

    # Check to see if the file exists
    if File.exists?(configuration_file)
      config_raw = File.read(configuration_file)
      config = JSON.parse(config_raw)
    else
      config = {}
    end

    # determine if a configuration exists for the named group
    if !config.key?(group)
      config[group] = {
        "count" => options[:count]
      }
    end

    # Determine if a previous group should be removed
    unless options['no-delete']
      if config[group]['count'] > 1

        # Determine the name of the group to delete
        group_remove_name = format('%s-%s', group, config[group]['count'] - 1)

        cmds << format('az group delete -n %s -y --no-wait', group_remove_name)
      end
    end

    # Create the new group
    # Determine the new group name
    group_name = format("%s-%s", group, config[group]['count'])
    cmds << format('az group create -n "%s" -l "%s"', group_name, options[:location])

    # Work out the command to run the deployment
    deployment_name = format("%s-deploy", group_name)
    deploy_cmd = format('az group deployment create --template-uri %s --parameters @%s -g %s -n %s', uri, parameters, group_name, deployment_name)
    if options['no-wait']
      deploy_cmd += "  --no-wait"
    end
    cmds << deploy_cmd

    # Iterate around the commands and execute each in turn
    cmds.each do |cmd|
      puts cmd
      unless options[:dryrun]
        Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
          while line = stdout_err.gets
            puts line
          end

          exit_status = wait_thr.value
          unless exit_status.success?
            puts "FAILED !!! #{cmd}"
          end
        end
      end
    end

    # Increment the counter
    config[group]['count'] += 1

    # Write out the configuration file
    unless options[:dryrun]
      if !File.exists?(File.dirname(configuration_file))
        Dir.mkdir(File.dirname(configuration_file))
      end
      File.open(configuration_file, "w") do |f|
        f.write(config.to_json)
      end
    end

  end

  desc "status [RESOURCE_GROUP]", "Check the status of a deployment in Azure"
  def status(group)

    # Read the configuration file for this task to determine the group to delete and
    # the one to create
    configuration_file = File.join(File.dirname(__FILE__), '../..', '.thor/deploy.json')

    # Check to see if the file exists
    if File.exists?(configuration_file)
      config_raw = File.read(configuration_file)
      config = JSON.parse(config_raw)
    else
      config = {}
    end

    resource_group_name = format('%s-%s', group, config[group]["count"] - 1)

    # Check that a group exists as a key in the configuration
    if config.key?(group) 

      # configure the command to run to display the status
      
      deployment_name = format('%s-deploy', resource_group_name)
      status_cmd = format('az group deployment show -g %s -n %s', resource_group_name, deployment_name)

      Open3.popen2e(status_cmd) do |stdin, stdout_err, wait_thr|
          while line = stdout_err.gets
            puts line
          end

          exit_status = wait_thr.value
          unless exit_status.success?
            puts "FAILED !!! #{cmd}"
          end
        end

    else

      puts format("Unable to find resource group: %s", resource_group_name)
    end
  end

end