case node["platform_family"]
  when "rhel"
    include_recipe "yum"
    include_recipe "yum::epel"
  
    if node['platform_version'].to_f < 6.0
      include_recipe "jpackage"
    end
  end

case node['platform']
  when "ubuntu"
    execute "update packages cache" do
      command "apt-get update"
    end
  end

node.set['tomcat']['java_options'] = "#{node['tomcat']['java_options']} " + "#{node['cookbook-qubell-tomcat']['add_java_options'].join(' ')}"
include_recipe "timezone-ii"

directory "/etc/profile.d" do
  mode 00755
end

file "/etc/profile.d/tz.sh" do
  content "export TZ=#{node['cookbook-qubell-tomcat']['timezone']}"
  mode 00755
end

include_recipe "tomcat"

case node["platform_family"]
  when "rhel"
    service "iptables" do
      action :stop
    end
  when "debian"
    service "ufw" do
      action :stop
    end
  end
