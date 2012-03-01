require File.expand_path('../../spec_helper', __FILE__)
require File.expand_path('../../../lib/rest-assured/api/server', __FILE__)

module RestAssured
  describe Server do
    around do |example|
      Server.reset_instance
      example.run
      Server.reset_instance
    end

    it 'khows when it is up' do
      AppSession.stub(:new).and_return(session = stub(:alive? => true).as_null_object)
      Utils::PortExplorer.stub(:port_free? => false)

      Server.start
      Server.up?.should == true
    end

    context 'knows that it is NOT up' do
      it 'if it has not been started' do
        Server.up?.should == false
      end

      it 'if it is starting at the moment' do
        AppSession.stub(:new).and_return(session = stub(:alive? => true).as_null_object)
        Utils::PortExplorer.stub(:port_free? => true)
        Server.start!

        Server.up?.should == false
      end
    end

    context 'when starts' do
      it 'makes sure no previous session is running' do
        session = mock.as_null_object
        session.stub(:alive?).and_return(true, false)
        Utils::PortExplorer.stub(:port_free? => false)
        AppSession.stub(:new).and_return(session)

        session.should_receive(:stop).once
        Server.start!
        Server.start!
      end

      it 'builds application config' do
        AppSession.stub(:new).as_null_object

        opts = { :port => 34545, :database => ':memory:' }

        Config.should_receive(:build).with(opts)
        Server.start!(opts)
      end

      context 'sets up server address' do
        before do
          AppSession.stub(:new).as_null_object
        end

        it 'uses 127.0.0.1 as hostname' do
          RestAssured::Double.should_receive(:site=).with(/127\.0\.0\.1/)
          Server.start!
          Server.address.should =~ /127\.0\.0\.1/
        end

        it 'uses port from config' do
          RestAssured::Double.should_receive(:site=).with(/#{AppConfig.port}/)
            Server.start!
          Server.address.should =~ /#{AppConfig.port}/
        end

        it 'uses http by default' do
          RestAssured::Double.should_receive(:site=).with(/http[^s]/)
          Server.start!
          Server.address.should =~ /http[^s]/
        end

        it 'uses https if ssl is set in config' do
          AppConfig.ssl = true
          RestAssured::Double.should_receive(:site=).with(/https/)
          Server.start!
          Server.address.should =~ /https/
        end
      end

      describe 'async/sync start' do
        before do
          AppSession.stub(:new).and_return(session = stub(:alive? => false).as_null_object)
          Utils::PortExplorer.stub(:port_free? => true)

          @t = Thread.new do
            sleep 0.5
            session.stub(:alive?).and_return(true)
            Utils::PortExplorer.stub(:port_free? => false)
          end
        end

        after do
          @t.join
        end

        it 'does not wait for Application to come up' do
          Server.start!
          Server.up?.should == false
        end

        it 'can wait until Application is up before passing control' do
          Server.start
          Server.up?.should == true
        end
      end
    end

    context 'when stopped' do
      it 'stops application subprocess' do
        AppSession.stub(:new).and_return(session = stub(:alive? => false))
        Server.start!

        session.should_receive(:stop)
        Server.stop
      end
    end

    it 'stops application subprocess when current process exits' do
      res_file = Tempfile.new('res')
      AppSession.stub(:new).and_return(session = mock.as_null_object)
      session.stub(:alive?).and_return(false)
      session.stub(:stop) do
        res_file.write "stopped"
        res_file.rewind
      end
      fork do
        Server.start!
      end
      Process.wait
      res_file.read.should == 'stopped'
    end
  end
end
