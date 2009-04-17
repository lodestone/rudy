
module Rudy; module CLI; 
module AWS; module EC2;
  
  class Candy < Rudy::CLI::CommandBase
    
    def status_valid?
      avail = Rudy::Utils.service_available?('status.aws.amazon.com', 80, 5)
      raise ServiceUnavailable, 'status.aws.amazon.com' unless avail
      true
    end
    def status
      url = 'http://status.aws.amazon.com/rss/EC2.rss'
      # TODO: Move to Rudy::AWS
      ec2 = Rudy::Utils::RSSReader.run(url) || {}
      
      # TODO: Create Storable object
      if @@global.format == 'yaml'
        puts ec2.to_yaml
      elsif @@global.format == 'json'
        require 'json'
        puts ec2.to_json
      else
        puts "Updated: #{ec2[:pubdate]} (updated every #{ec2[:ttl]} minutes)"
        ec2[:items].each do |i|
          puts
          puts '%s' % i[:title]
          puts '  %s: %s' % [i[:pubdate], i[:description]]
          
        end
      end
    end
    
    def ssh_valid?
      if @option.pkey
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise "Insecure permissions for #{@option.pkey}" unless (File.stat(@option.pkey).mode & 600) == 0
      end
      if @option.group
        rgroup = Rudy::AWS::EC2::Groups.new(@@global.accesskey, @@global.secretkey, @@global.region)
        raise "Cannot supply group and instance ID" if @option.instid
        raise "Group #{@option.group} does not exist" unless rgroup.exists?(@option.group)
      end
      if @option.instid && !Rudy::Utils.is_id?(:instance, @option.instid)
        raise "#{@option.instid} is not an instance ID" 
      end
      true
    end
    def ssh
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all
      opts[:id] = @option.instid if @option.instid
      
      # Options to be sent to Net::SSH
      ssh_opts = { :user => @option.user || Rudy.sysinfo.user, :debug => nil  }
      if @option.pkey 
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise InsecureKeyPermissions, @option.pkey unless File.stat(@option.pkey).mode == 33152
        ssh_opts[:keys] = @option.pkey 
      end
      
      
      # The user specified a command to run. We won't create an interactive
      # session so we need to prepare the command and its arguments
      if @argv.first
        command, command_args = @argv.shift, @argv || []
        puts "#{command} #{command_args.join(' ')}" if @@global.verbose > 1
      
      # otherwise, we'll open an ssh session or print command
      else
        command, command_args = :interactive_ssh, @option.print.nil?
      end
      
      checked = false
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      lt = rudy.list_group(opts[:group], :running, opts[:id]) do |inst|
        
        # Print header
        if @@global.quiet
          print "You are #{ssh_opts[:user].bright}. " if !checked # only the 1st
        else
          print "Connecting #{ssh_opts[:user].bright}@#{inst.dns_public} "
          puts "(#{inst.awsid}, groups: #{inst.groups.join(', ')})"
        end
        
        # Make sure we want to run this command on all instances
        if !checked && command != :interactive_ssh 
          execute_check(:medium) if ssh_opts[:user] == "root"
          checked = true
        end
        
        # Open the connection and run the command
        rbox = Rye::Box.new(inst.dns_public, ssh_opts)
        ret = rbox.send(command, command_args)
        puts ret unless command == :interactive_ssh
      end
    end

    def copy_valid?
      raise "You must supply a source and a target. See rudy-ec2 #{@alias} -h" unless @argv.size >= 2
      raise "You cannot download and upload at the same time" if @option.download && @alias == 'upload'
      raise "You cannot download and upload at the same time" if @option.upload && @alias == 'download'
      true
    end
    def copy
      
      opts = {}
      opts[:group] = @option.group if @option.group
      opts[:group] = :any if @option.all

      opts[:id] = @argv.shift if Rudy::Utils.is_id?(:instance, @argv.first)
      opts[:id] &&= [opts[:id]].flatten
      
      # * +:recursive: recursively transfer directories (default: false)
      # * +:preserve: preserve atimes and ctimes (default: false)
      # * +:task+ one of: :upload (default), :download.
      # * +:paths+ an array of paths to copy. The last element is the "to" path.
      opts[:recursive] = @option.recursive ? true : false
      opts[:preserve] = @option.preserve ? true : false
      
      opts[:paths] = @argv
      opts[:dest] = opts[:paths].pop
    
      opts[:task] = :download if %w(dl download).member?(@alias) || @option.download
      opts[:task] = :upload if %w(ul upload).member?(@alias)
      opts[:task] ||= :upload
    
      # Options to be sent to Net::SSH
      ssh_opts = { :user => @option.user || Rudy.sysinfo.user, :debug => nil  }
      ssh_opts[:keys] = @option.pkey if @option.pkey

      if @option.pkey
        raise "Cannot find file #{@option.pkey}" unless File.exists?(@option.pkey)
        raise "Insecure permissions for #{@option.pkey}" unless (File.stat(@option.pkey).mode & 600) == 0
      end

      checked = false
      rudy = Rudy::AWS::EC2::Instances.new(@@global.accesskey, @@global.secretkey, @@global.region)
      lt = rudy.list_group(opts[:group], :running, opts[:id]) do |inst|
        
        if @option.print
          Rudy::Utils.scp_command inst.dns_public, @option.pkey, @option.user, opts[:paths], opts[:dest], (opts[:task] == :download), false, @option.print
          next
        end
        
        # Print header
        if @@global.quiet
          print "You are #{ssh_opts[:user].bright}. " if !checked # only the 1st
        else
          print "Connecting #{ssh_opts[:user].bright}@#{inst.dns_public} "
          puts "(#{inst.awsid}, groups: #{inst.groups.join(', ')})"
        end
        
        # Make sure we want to run this command on all instances
        if !checked
          execute_check(:medium) if ssh_opts[:user] == "root"
          checked = true
        end
        
        scp_opts = {
          :recursive => opts[:recursive],
          :preserve => opts[:preserve],
          :chunk_size => 16384
        }

        Candy.scp(opts[:task], inst.dns_public, @option.user, @option.pkey, opts[:paths], opts[:dest], scp_opts)
        puts 
        puts unless @@global.quiet
      end

    end
    
    
  private
    
    def Candy.scp(task, host, user, keypairpath, paths, dest, opts)
      
      connect_opts = {}
      connect_opts[:keys] = [keypairpath] if keypairpath
      
      Net::SCP.start(host, user, connect_opts) do |scp|
        
        paths.each do |path| 
          prev_path = nil
          scp.send("#{task}!", path, dest, opts) do |ch, name, sent, total|
            msg = ((prev_path == name) ? "\r" : "\n") # new line for new file
            msg << "#{name}: #{sent}/#{total}"  # otherwise, update the same line
            print msg
            STDOUT.flush        # update the screen every cycle
            prev_path = name
          end
          puts unless prev_path == path
        end
        
      end
    end
    
    
    
  end
  
  
end; end
end; end
