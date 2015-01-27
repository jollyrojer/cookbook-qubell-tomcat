#
#Recipe will deploy war to tomcat
#
#download war file
require 'uri'
node['cookbook-qubell-tomcat']['war']['uri'].each_with_index do |uri, uri_index|
  service "tomcat" do
    service_name "tomcat#{node["tomcat"]["base_version"]}"
    supports :restart => false, :status => true
    action :stop
  end
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

      #cleanup tomcat before deploy
      file "#{node['tomcat']['webapp_dir']}/#{file_name}" do
        action :delete
      end

      file "#{node['tomcat']['context_dir']}/#{app_name}.xml" do
        action :delete
      end

      directory "#{node['tomcat']['webapp_dir']}/#{app_name}" do
        recursive true
        action :delete
      end

      #deploy war
      bash "copy #{file_path} to tomcat" do
        user "root"
        code <<-EOH
        cp -fr #{file_path} #{node['tomcat']['webapp_dir']}/#{file_name}
        chmod 644 #{node['tomcat']['webapp_dir']}/#{file_name}
        chown #{node['tomcat']['user']}:#{node['tomcat']['group']} #{node['tomcat']['webapp_dir']}/#{file_name}
        EOH
      end

      #create context file
      if (! node['cookbook-qubell-tomcat']['context'].nil? and node["cookbook-qubell-tomcat"]["context"].to_hash.fetch("context_attrs", {}) != {} )
          template "#{node['tomcat']['context_dir']}/#{app_name}.xml" do
            owner node["tomcat"]["user"]
            group node["tomcat"]["group"]
            source "context.xml.erb"
            variables({
            :context_attrs => node["cookbook-qubell-tomcat"]["context"].to_hash.fetch("context_attrs", {}),
            :context_nodes => node["cookbook-qubell-tomcat"]["context"].to_hash.fetch("context_nodes", [])
          }) 
        end
      end

      service "tomcat" do
        service_name "tomcat#{node["tomcat"]["base_version"]}"
        supports :restart => false, :status => true
        action :start
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
