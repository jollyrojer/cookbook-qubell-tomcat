require 'minitest/spec'

describe_recipe 'cookbook-qubell-tomcat::deploy_libs' do
  it "deploy log4j-1.2.17.jar to tomcat libs" do
    assert File.exist?("#{node['tomcat']['lib_dir']}/log4j-1.2.17.jar")
  end
end
