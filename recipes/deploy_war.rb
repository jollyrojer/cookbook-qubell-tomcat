#
#Recipe will deploy war to tomcat
#
#download war file
require 'uri'
node['cookbook-qubell-tomcat']['war']['uri'].each_with_index do |uri, uri_index|
  path = node['cookbook-qubell-tomcat']['war']['path'][uri_index] 
  destname = "#{path[/^\/?(.*)/,1].strip}"
 
  if destname.include?("/")
    fail "war.path  must not contain /"
  end
  if destname.empty? 
    file_name = "ROOT.war"
  else
    file_name = "#{destname}.war"
  end


  if ( uri.start_with?('http', 'ftp') )
    ext_name = File.extname(file_name)
    app_name = file_name[0...-4]
    
    remote_file "/tmp/#{file_name}" do
      source uri
    end
    
    file_path = "/tmp/#{file_name}"
    
  elsif ( uri.start_with?('file') )
    url = uri
    file_path = URI.parse(url).path
    ext_name =  File.extname(file_name)
    app_name = File.basename(file_name)[0...-4]
  end

  if ( ! %w{.war .jar}.include?(ext_name))
       fail "appname must be .war or .jar"
  end
      
  directory "/tmp/checksum/" do
    action :create
  end
  file_md5 = "/tmp/checksum/#{app_name}.md5"
  bash "check war md5" do
    user "root"
    code <<-EOH
      md5sum -b #{file_path} > #{file_md5}
    EOH
    not_if "md5sum -c #{file_md5}"
    notifies :stop,    "service[tomcat]", :immediately
    notifies :delete, "file[#{node['tomcat']['webapp_dir']}/#{file_name}]", :immediately 
    notifies :delete, "file[#{node['tomcat']['context_dir']}/#{app_name}.xml]", :immediately
    notifies :delete, "directory[#{node['tomcat']['webapp_dir']}/#{app_name}]", :immediately
    notifies :run,    "bash[copy #{file_path} to tomcat]", :immediately
    notifies :create, "template[#{node['tomcat']['context_dir']}/#{app_name}.xml]", :immediately
    notifies :start,    "service[tomcat]", :immediately
  end

  service "tomcat" do
    service_name "tomcat#{node["tomcat"]["base_version"]}"
    supports :restart => false, :status => true
    action :nothing
  end

  #cleanup tomcat before deploy
  file "#{node['tomcat']['webapp_dir']}/#{file_name}" do
    action :nothing
    only_if  { File.exists?("#{node['tomcat']['webapp_dir']}/#{file_name}") }
  end

  file "#{node['tomcat']['context_dir']}/#{app_name}.xml" do
    action :nothing
    only_if  { File.exists?("#{node['tomcat']['context_dir']}/#{app_name}.xml") }
  end

  directory "#{node['tomcat']['webapp_dir']}/#{app_name}" do
    recursive true
    action :nothing
    only_if  { File.exists?("#{node['tomcat']['webapp_dir']}/#{app_name}") }
  end

  #deploy war
  bash "copy #{file_path} to tomcat" do
    user "root"
    code <<-EOH
    cp -fr #{file_path} #{node['tomcat']['webapp_dir']}/#{file_name}
    chmod 644 #{node['tomcat']['webapp_dir']}/#{file_name}
    chown #{node['tomcat']['user']}:#{node['tomcat']['group']} #{node['tomcat']['webapp_dir']}/#{file_name}
    EOH
    action :nothing
  end

  #create context file
  template "#{node['tomcat']['context_dir']}/#{app_name}.xml" do
    owner node["tomcat"]["user"]
    group node["tomcat"]["group"]
    source "context.xml.erb"
    variables({
      :context_attrs => node["cookbook-qubell-tomcat"]["context"].to_hash.fetch("context_attrs", {}),
      :context_nodes => node["cookbook-qubell-tomcat"]["context"].to_hash.fetch("context_nodes", [])
    }) 
    only_if { node["cookbook-qubell-tomcat"]["context"].to_hash.fetch("context_attrs", {}) != {} }
    action :nothing
  end

  bash "Waiting application start" do
    user "root"
    code <<-EOH
      i=0
      http=000
      while [ $i -le 77 -a "$http" == "000" ]; do
        echo "$i"
        sleep 10
        ((i++))
        http=`curl -s -w "%{http_code}" "http://localhost:8080/#{destname}" -o /dev/null`
      done

      echo "http: $http"

      [ "$http" ~= "^[045]" ] && exit 1
      exit 0
      EOH
  end
end    
