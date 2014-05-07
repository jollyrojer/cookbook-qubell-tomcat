#
#Tomcat component additional libs installation to tomcat
#

service "tomcat" do
  service_name "tomcat#{node["tomcat"]["base_version"]}"
  supports :restart => false, :status => true
  action :nothing
end

require 'uri'
lib_uri = node['cookbook-qubell-tomcat']['lib_uri']
lib_uri.each do |lib|
  uri = URI.parse(lib)
  file_name = File.basename(uri.path)
  ext_name = File.extname(file_name)
  target_file = "/tmp/#{file_name}"

  #check is extention zip|tar.gz
  #if ext_name != ('zip','gz','jar') 
  if ( ! %w{.zip .gz .jar}.include?(ext_name))
    fail "not supported"
  end

  #download to target_file
  if ( lib.start_with?('http','ftp'))
    remote_file target_file do
      source lib
    end
  elsif ( lib.start_with?('file'))
    target_file = URI.parse(lib).path 
  else
    fail "not supported URI"
  end

  file_name = File.basename(target_file)

  #extract archive to tomcat libs
  case ext_name
  when ".gz"
    bash "extract #{target_file}" do
      user "root"
      code <<-EOH
      tar -xzvf #{target_file} -C #{node['tomcat']['lib_dir']}/
      chmod 644 #{node['tomcat']['lib_dir']}/#{file_name}
      EOH
      notifies :restart, "service[tomcat]", :delayed
    end
  when ".zip"
    package "zip" do
      action :install
    end
    bash "extract #{target_file}" do
      user "root"
      code <<-EOH
      unzip -o #{target_file} -d #{node['tomcat']['lib_dir']}/
      chmod 644 #{node['tomcat']['lib_dir']}/#{file_name}
      EOH
      notifies :restart, "service[tomcat]", :delayed
    end
  #copy lib to tomcat libs
  when ".jar"
    bash "copy #{target_file}" do
      user "root"
      code <<-EOH
      cp -rf #{target_file} #{node['tomcat']['lib_dir']}/
      chmod 644 #{node['tomcat']['lib_dir']}/#{file_name}
      EOH
      notifies :restart, "service[tomcat]", :delayed
    end
  end
end
