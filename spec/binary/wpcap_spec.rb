require 'spec_helper'
require 'fakefs'
require 'wpcap/command'


module Wpcap
  describe Command do

    before :all do
      puts "Preparing FakeFs for Tests"
      wpcap_dir = File.expand_path "#{File.dirname(__FILE__)}../../../"
      FakeFS::FileSystem.clone(wpcap_dir)
    end

    before :each do
      Wpcap::Command.stub!(:capify).and_return(true)
      FileUtils.rm_r "/tmp/google" if Dir.exists? "/tmp/google"
      stub_request(:get, "http://wordpress.org/latest.tar.gz").
        with(:headers => {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "", :headers => {})
    end


    describe  :create do
      subject { Wpcap::Command.create(["google","/tmp"]) }

      it "creates an project directory at the passed in path" do
        prep_fake_wordpress(:new)

        subject
        Dir.exists?("/tmp/google").should eq true
        Dir.exists?("/tmp/google/app").should eq true
      end

      it "has a new valid wordpress install " do
        prep_fake_wordpress(:new)
        subject
        File.exists?("/tmp/google/app/wp-load.php").should eq true
      end
    end

    describe :build do
      subject { Wpcap::Command.build(["google"]) }
      it "responds to the create command" do
        
        Wpcap::Command.respond_to?(:build).should eq true
      end

      it "creates an project directory at the passed in path" do
        prep_fake_wordpress(:existing)
        subject
        Dir.exists?("/tmp/google").should eq true
        Dir.exists?("/tmp/google/app").should eq true
        File.exists?("/tmp/google/app/wp-load.php").should eq true
      end
    end

  end

end

def prep_fake_wordpress(type)
  FileUtils.mkdir_p "/tmp/wordpress"
  FileUtils.cp_r "spec/test_payloads/#{type}/."  , "/tmp/wordpress"
end
