
group "Config"
library :rudy, File.expand_path(File.join(GYMNASIUM_HOME, '..', 'lib'))

tryout "Machines" do
  ## drill "Setup vars", :dream => true do
  drill "Setup vars", true do
    @@config = Rudy::Config.new
    @@config.look_and_load   # looks for and loads config files
    @@reg, @@zon = @@config.defaults.region, @@config.defaults.zone 
    @@env, @@rol = @@config.defaults.environment, @@config.defaults.role
    true
  end
  
  dream 'SHA1', :hash
  xdrill "example stage is defined" do
    @@config.machines.stage
  end
  drill "has example AMIs by zone", ["ami-e348af8a", "ami-6ecde51a"] do
    [@@config.machines[:'us-east-1'].ami, @@config.machines[:'eu-west-1'].ami]
  end
  
  drill "can find us-east-1 AMI", 'ami-e348af8a' do
    @@config.machines.find(:"us-east-1", :ami)
  end
  drill "can find eu-west-1 AMI", 'ami-6ecde51a' do
    @@config.machines.find(:"eu-west-1", :ami)
  end
  drill "different default AMI for each zone", true do
    eu = @@config.machines.find(:"eu-west-1", :ami)
    us = @@config.machines.find(:"us-east-1", :ami)
    (eu != us && !eu.nil? && !us.nil?)
  end
  drill "conf hash and find are equal", true do
    conf = @@config.machines[@@env][@@rol]
    find = @@config.machines.find(@@env, @@rol)
    conf == find
  end
  drill "conf find and find_deferred are equal", true do
    find = @@config.machines.find(@@env, @@rol)
    find_def = @@config.machines.find_deferred(@@env, @@rol)
    find == find_def
  end
  
  drill "config has a gash", '87d792aefceb893b2d966828827c61636b0ace3e' do
    @@config.machines.gash
  end
  
end

