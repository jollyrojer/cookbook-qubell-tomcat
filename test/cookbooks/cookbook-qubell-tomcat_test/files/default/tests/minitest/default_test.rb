require 'minitest/spec'

describe_recipe 'cookbook-qubell-tomcat::default' do
  it "install tomcat6 package" do
    package("tomcat6").must_be_installed
  end
  it "tomcat is running" do
    service("tomcat6").must_be_running
  end
  it "firewall is disabled" do
    if node["platform_family"] == 'rhel'
      service("iptables").wont_be_running
    end
  end
end

sleep(20)
require 'socket'
require 'timeout'
def is_port_open?(ip, port)
  begin
    Timeout::timeout(1) do
      begin
        s = TCPSocket.new(ip, port)
        s.close
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        return false
      end
    end
  rescue Timeout::Error
  end

  return false
end

describe_recipe 'cookbook-qubell-tomcat::default' do
  it "tomcat is listening" do
    assert is_port_open?("#{node["ipaddress"]}", "#{node["tomcat"]["port"]}") == true, "Expected port #{node["tomcat"]["port"]} is open"
  end
end
