require 'spec_helper'
require 'socket'
require 'open3'

describe "Pkg::Util::Net" do
  let(:target)     { "/tmp/placething" }
  let(:target_uri) { "http://google.com" }
  let(:content)    { "stuff" }
  let(:rsync)      { "/bin/rsync" }
  let(:ssh)        { "/usr/local/bin/ssh" }

  describe "#fetch_uri" do
    context "given a target directory" do
      it "does nothing if the directory isn't writable" do
        File.stub(:writable?).with(File.dirname(target)) { false }
        File.should_receive(:open).never
        Pkg::Util::Net.fetch_uri(target_uri, target)
      end

      it "writes the content of the uri to a file if directory is writable" do
        File.should_receive(:writable?).once.with(File.dirname(target)) { true }
        File.should_receive(:open).once.with(target, 'w')
        Pkg::Util::Net.fetch_uri(target_uri, target)
      end
    end
  end

  describe "hostname utils" do

    describe "hostname" do
      it "should return the hostname of the current host" do
        Socket.stub(:gethostname) { "foo" }
        Pkg::Util::Net.hostname.should eq("foo")
      end
    end

    describe "check_host" do
      context "with required :true" do
        it "should raise an exception if the passed host does not match the current host" do
          Socket.stub(:gethostname) { "foo" }
          Pkg::Util::Net.should_receive(:check_host).and_raise(RuntimeError)
          expect{ Pkg::Util::Net.check_host("bar", :required => true) }.to raise_error(RuntimeError)
        end
      end

      context "with required :false" do
        it "should return nil if the passed host does not match the current host" do
          Socket.stub(:gethostname) { "foo" }
          Pkg::Util::Net.check_host("bar", :required => false).should be_nil
        end
      end
    end
  end

  describe "remote_ssh_cmd" do
    it "should fail if ssh is not present" do
      Pkg::Util::Tool.stub(:find_tool).with("ssh") { fail }
      Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_raise(RuntimeError)
      expect{ Pkg::Util::Net.remote_ssh_cmd("foo", "bar") }.to raise_error(RuntimeError)
    end

    context "without output captured" do
      it "should execute a command :foo on a host :bar using Kernel" do
        Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
        Kernel.should_receive(:system).with("#{ssh} -t foo 'bar'")
        Pkg::Util::Execution.should_receive(:success?).and_return(true)
        Pkg::Util::Net.remote_ssh_cmd("foo", "bar")
      end

      it "should escape single quotes in the command" do
        Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
        Kernel.should_receive(:system).with("#{ssh} -t foo 'b'\\''ar'")
        Pkg::Util::Execution.should_receive(:success?).and_return(true)
        Pkg::Util::Net.remote_ssh_cmd("foo", "b'ar")
      end

      it "should raise an error if ssh fails" do
        Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
        Kernel.should_receive(:system).with("#{ssh} -t foo 'bar'")
        Pkg::Util::Execution.should_receive(:success?).and_return(false)
        expect{ Pkg::Util::Net.remote_ssh_cmd("foo", "bar") }.to raise_error(RuntimeError, /Remote ssh command failed./)
      end
    end

    context "with output captured" do
      it "should execute a command :foo on a host :bar using Open3" do
        Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
        Open3.should_receive(:capture3).with("#{ssh} -t foo 'bar'")
        Pkg::Util::Execution.should_receive(:success?).and_return(true)
        Pkg::Util::Net.remote_ssh_cmd("foo", "bar", true)
      end

      it "should escape single quotes in the command" do
        Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
        Open3.should_receive(:capture3).with("#{ssh} -t foo 'b'\\''ar'")
        Pkg::Util::Execution.should_receive(:success?).and_return(true)
        Pkg::Util::Net.remote_ssh_cmd("foo", "b'ar", true)
      end

      it "should raise an error if ssh fails" do
        Pkg::Util::Tool.should_receive(:check_tool).with("ssh").and_return(ssh)
        Open3.should_receive(:capture3).with("#{ssh} -t foo 'bar'")
        Pkg::Util::Execution.should_receive(:success?).and_return(false)
        expect{ Pkg::Util::Net.remote_ssh_cmd("foo", "bar", true) }.to raise_error(RuntimeError, /Remote ssh command failed./)
      end
    end
  end

  describe "#rsync_to" do
    it "should fail if rsync is not present" do
      Pkg::Util::Tool.stub(:find_tool).with("rsync") { fail }
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_raise(RuntimeError)
      expect{ Pkg::Util::Net.rsync_to("foo", "bar", "boo") }.to raise_error(RuntimeError)
    end

    it "should rsync 'thing' to 'foo@bar:/home/foo' with flags '-rHlv -O --no-perms --no-owner --no-group --ignore-existing'" do
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_return(rsync)
      Pkg::Util::Execution.should_receive(:ex).with("#{rsync} -rHlv -O --no-perms --no-owner --no-group --ignore-existing thing foo@bar:/home/foo")
      Pkg::Util::Net.rsync_to("thing", "foo@bar", "/home/foo")
    end

    it "rsyncs 'thing' to 'foo@bar:/home/foo' with flags that don't include --ignore-existing" do
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_return(rsync)
      Pkg::Util::Execution.should_receive(:ex).with("#{rsync} -rHlv -O --no-perms --no-owner --no-group thing foo@bar:/home/foo")
      Pkg::Util::Net.rsync_to("thing", "foo@bar", "/home/foo", [])
    end

    it "rsyncs 'thing' to 'foo@bar:/home/foo' with flags that don't include arbitrary flags" do
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_return(rsync)
      Pkg::Util::Execution.should_receive(:ex).with("#{rsync} -rHlv -O --no-perms --no-owner --no-group --foo-bar --and-another-flag thing foo@bar:/home/foo")
      Pkg::Util::Net.rsync_to("thing", "foo@bar", "/home/foo", ["--foo-bar", "--and-another-flag"])
    end
  end

  describe "#rsync_from" do
    it "should fail if rsync is not present" do
      Pkg::Util::Tool.stub(:find_tool).with("rsync") { fail }
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_raise(RuntimeError)
      expect{ Pkg::Util::Net.rsync_from("foo", "bar", "boo") }.to raise_error(RuntimeError)
    end

    it "should rsync 'thing' from 'foo@bar' to '/home/foo' with flags '-rHlv -O --no-perms --no-owner --no-group'" do
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_return(rsync)
      Pkg::Util::Execution.should_receive(:ex).with("#{rsync} -rHlv -O --no-perms --no-owner --no-group foo@bar:thing /home/foo")
      Pkg::Util::Net.rsync_from("thing", "foo@bar", "/home/foo")
    end

    it "rsyncs 'thing' from 'foo@bar:/home/foo' with flags that don't include arbitrary flags" do
      Pkg::Util::Tool.should_receive(:check_tool).with("rsync").and_return(rsync)
      Pkg::Util::Execution.should_receive(:ex).with("#{rsync} -rHlv -O --no-perms --no-owner --no-group --foo-bar --and-another-flag foo@bar:thing /home/foo")
      Pkg::Util::Net.rsync_from("thing", "foo@bar", "/home/foo", ["--foo-bar", "--and-another-flag"])
    end
  end

  describe "#curl_form_data" do
    let(:curl) {"/bin/curl"}
    let(:form_data) {["name=FOO"]}
    let(:options) { {:quiet => true} }

    it "should return false on failure" do
      Pkg::Util::Tool.should_receive(:check_tool).with("curl").and_return(curl)
      Pkg::Util::Execution.should_receive(:ex).with("#{curl} -i #{target_uri}").and_return(false)
      Pkg::Util::Net.curl_form_data(target_uri).should be_false
    end


    it "should curl with just the uri" do
      Pkg::Util::Tool.should_receive(:check_tool).with("curl").and_return(curl)
      Pkg::Util::Execution.should_receive(:ex).with("#{curl} -i #{target_uri}")
      Pkg::Util::Net.curl_form_data(target_uri)
    end

    it "should curl with the form data and uri" do
      Pkg::Util::Tool.should_receive(:check_tool).with("curl").and_return(curl)
      Pkg::Util::Execution.should_receive(:ex).with("#{curl} -i #{form_data[0]} #{target_uri}")
      Pkg::Util::Net.curl_form_data(target_uri, form_data)
    end

    it "should curl with form data, uri, and be quiet" do
      Pkg::Util::Tool.should_receive(:check_tool).with("curl").and_return(curl)
      Pkg::Util::Execution.should_receive(:ex).with("#{curl} -i #{form_data[0]} #{target_uri} >/dev/null 2>&1")
      Pkg::Util::Net.curl_form_data(target_uri, form_data, options)
    end

  end

  describe "#print_url_info" do
    it "should output correct formatting" do
      Pkg::Util::Net.should_receive(:puts).with("\n////////////////////////////////////////////////////////////////////////////////\n\n
  Build submitted. To view your build progress, go to\n#{target_uri}\n\n
////////////////////////////////////////////////////////////////////////////////\n\n")
      Pkg::Util::Net.print_url_info(target_uri)
    end
  end
end
