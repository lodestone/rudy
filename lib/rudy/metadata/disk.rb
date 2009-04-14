

module Rudy
class Disk < Storable
  include Rudy::Huxtable
  include Rudy::MetaData::ObjectBase
  
  field :rtype
  field :awsid
  
  field :region
  field :zone
  field :environment
  field :role
  field :position
  field :path
  
  field :device
  field :size
  #field :backups => Array
  
  def initialize(path=nil, size=nil, device=nil)
    @path, @size, @device = path, size, device
    @rtype = 'disk'
    @region = @@global.region
    @zone = @@global.zone
    @environment = @@global.environment
    @role = @@global.role
    @position = @@global.position
    postprocess
  end
  
  def name
    sep=File::SEPARATOR
    dirs = @path.split sep if @path && !@path.empty?
    dirs.shift while dirs && (dirs[0].nil? || dirs[0].empty?)
    super("disk", @zone, @environment, @role, @position, *dirs)
  end
  
  def to_query(more=[], less=[])
    super([:path, *more], less)  # Add path to the default fields
  end
  
  def to_select(more=[], less=[])
    super([:path, *more], less) 
  end
  
  # Does this disk have enough info to be saved or used?
  # The test is based on the same criteria for building
  # SimpleDB queries. 
  def valid?
    criteria = build_criteria([:path]).flatten
    criteria.size == criteria.compact.size
  end
  
  
  def postprocess
    @size &&= @size.to_i
  end
  
end
end




__END__

def format(instance)
  raise "No instance supplied" unless instance
  raise "Disk not valid" unless self.valid?

  begin
    puts "Creating the filesystem (mkfs.ext3 -F #{disk.device})".bright
    ssh_command instance.dns_public, current_user_keypairpath, @@global.user, "mkfs.ext3 -F #{disk.device}"
    sleep 1
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error formatting #{disk.path}: #{ex.message}"
  end
  true
end
def mount(instance)
  raise "No instance supplied" unless instance
  disk = find_disk(opts[:disk] || opts[:path])
  raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk
  switch_user(:root)
  begin
    puts "Mounting #{disk.device} to #{disk.path}".bright
    ssh_command instance.dns_public, current_user_keypairpath, @@global.user, "mkdir -p #{disk.path} && mount -t ext3 #{disk.device} #{disk.path}"
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error mounting #{disk.path}: #{ex.message}"
  end
  true
end

def unmount(instance)
  raise "No instance supplied" unless instance
  disk = find_disk(opts[:disk] || opts[:path])
  raise "Disk #{opts[:disk] || opts[:path]} cannot be found" unless disk
  switch_user(:root)
  begin
    puts "Unmounting #{disk.path}...".bright
    ssh_command instance.dns_public, current_user_keypairpath, global.user, "umount #{disk.path}"
    sleep 1
  rescue => ex
    @logger.puts ex.backtrace if debug?
    raise "Error unmounting #{disk.path}: #{ex.message}"
  end
  true
end
