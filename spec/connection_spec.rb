# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Braspag::Connection do
  let(:merchant_id) { "{12345678-1234-1234-1234-123456789000}" }
  let(:crypto_key) { "{84BE7E7F-698A-6C74-F820-AE359C2A07C2}" }
  let(:crypto_url) { "http://localhost:9292" }

  let(:braspag_environment) { "homologation" }

  let(:braspag_homologation_url) { "https://homologacao.pagador.com.br" }
  let(:braspag_production_url) { "https://transaction.pagador.com.br" }

  let(:braspag_config) do
    config = {}
    config[ENV["BRASPAG_ENV"]] = {
      "environment" => braspag_environment,
      "merchant_id" => merchant_id,
      "crypto_key"  => crypto_key,
      "crypto_url"  => crypto_url
    }
    config
  end

  before(:all) do
    @connection = Braspag::Connection.clone
  end

  context "changing default config file path" do
    before :each do
      @original_path = Braspag.config_file_path
    end

    after :each do
      Braspag.config_file_path = @original_path
    end

    it "should read config from a different path when specified" do
      connection = Braspag::Connection.clone

      Braspag.config_file_path = '/some/crazy/path'

      YAML.should_receive(:load_file).
        with("/some/crazy/path").
        and_return(braspag_config)

      connection.instance
    end
  end

  it "should read config/braspag.yml when alloc first instance" do
    YAML.should_receive(:load_file)
        .with("config/braspag.yml")
        .and_return(braspag_config)
    @connection.instance
  end

  it "should not read config/braspag.yml when alloc a second instance" do
    YAML.should_not_receive(:load_file)
    @connection.instance
  end

  it "should generate an exception when BRASPAG_ENV is nil" do
    ENV.should_receive(:[])
       .with("BRASPAG_ENV")
       .and_return(nil)

    expect {
      Braspag::Connection.clone.instance
    }.to raise_error Braspag::Connection::InvalidEnv
  end

  it "should generate an exception when BRASPAG_ENV is empty" do
    ENV.should_receive(:[])
       .twice
       .with("BRASPAG_ENV")
       .and_return("")

    expect {
      Braspag::Connection.clone.instance
    }.to raise_error Braspag::Connection::InvalidEnv
  end

  it "should generate an exception when merchant_id is not in a correct format" do
    braspag_config[ENV["BRASPAG_ENV"]]["merchant_id"] = "A" * 38

    YAML.should_receive(:load_file)
        .with("config/braspag.yml")
        .and_return(braspag_config)

    expect {
      Braspag::Connection.clone.instance
    }.to raise_error Braspag::Connection::InvalidMerchantId
  end

  it { @connection.instance.crypto_url.should == crypto_url }
  it { @connection.instance.crypto_key.should == crypto_key }
  it { @connection.instance.merchant_id.should == merchant_id }

  [:braspag_url, :merchant_id, :crypto_url, :crypto_key,
    :options, :environment].each do |attribute|

    it { @connection.instance.should respond_to(attribute) }

  end

  context "when there is pagador_url and protected_card_url on configuration" do
    let(:pagador_url) { "http://foo.bar" }
    let(:protected_card_url) { "http://bar.foo" }

    before do
      braspag_config[ENV["BRASPAG_ENV"]]["pagador_url"] = pagador_url
      braspag_config[ENV["BRASPAG_ENV"]]["protected_card_url"] = protected_card_url
      YAML.should_receive(:load_file).and_return(braspag_config)
    end

    subject { Braspag::Connection.clone.instance }

    its(:braspag_url) { should == pagador_url }
    its(:protected_card_url) { should == protected_card_url }
  end

  describe "#production?" do
    it "should return true when environment is production" do
      braspag_config[ENV["BRASPAG_ENV"]]["environment"] = "production"

      YAML.should_receive(:load_file)
          .and_return(braspag_config)

      Braspag::Connection.clone.instance.production?.should be_true
    end

    it "should return false when environment is not production" do
      braspag_config[ENV["BRASPAG_ENV"]]["environment"] = "homologation"

      YAML.should_receive(:load_file)
          .and_return(braspag_config)

      Braspag::Connection.clone.instance.production?.should be_false
    end
  end

  describe "#homologation?" do
    it "should return true when environment is homologation" do
      braspag_config[ENV["BRASPAG_ENV"]]["environment"] = "homologation"

      YAML.should_receive(:load_file)
          .and_return(braspag_config)

      Braspag::Connection.clone.instance.homologation?.should be_true
    end

    it "should return false when environment is not homologation" do
      braspag_config[ENV["BRASPAG_ENV"]]["environment"] = "production"

      YAML.should_receive(:load_file)
          .and_return(braspag_config)

      Braspag::Connection.clone.instance.homologation?.should be_false
     end
  end

  describe "#braspag_url" do
    context "when environment is homologation" do
      it "should return the Braspag homologation url" do
        braspag_config[ENV["BRASPAG_ENV"]]["environment"] = "homologation"

        YAML.should_receive(:load_file)
            .and_return(braspag_config)

        connection = Braspag::Connection.clone.instance
        connection.braspag_url.should == braspag_homologation_url
      end
    end

    context "when environment is production" do
      it "should return the Braspag production url" do
        braspag_config[ENV["BRASPAG_ENV"]]["environment"] = "production"

        YAML.should_receive(:load_file)
            .and_return(braspag_config)

        connection = Braspag::Connection.clone.instance
        connection.braspag_url.should == braspag_production_url
      end
    end
  end

  describe "#savon_client" do
    let(:wsdl_uri)        { 'http://localhost?wsdl' }
    let(:proxy)           { nil }
    let(:global_settings) { {} }

    before do
      Braspag.proxy_address = proxy
      Braspag.savon_global_options = global_settings
    end

    context "with local setting" do
      it "should set the settings on client" do
        Savon.should_receive(:client).with(:wsdl => wsdl_uri, :logger_level => :info)

        Braspag::Connection.clone.instance.savon_client(wsdl_uri, :logger_level => :info)
      end
    end

    context "with proxy address set" do
      let(:proxy) { 'http://some.proxy.com:3444' }

      it "should set the proxy on client" do
        Savon.should_receive(:client).with(:wsdl => wsdl_uri, :proxy => proxy)

        Braspag::Connection.clone.instance.savon_client(wsdl_uri)
      end
    end

    context "with global setting" do
      let(:global_settings) { {:log => false} }

      it "should set the settings on client" do
        Savon.should_receive(:client).with(:wsdl => wsdl_uri, :log => false)

        Braspag::Connection.clone.instance.savon_client(wsdl_uri)
      end
    end

    context "with local setting, global settings and proxy" do
      let(:proxy) { 'http://some.proxy.com:3444' }
      let(:global_settings) { {:log => false} }

      it "should set the settings and proxy on client" do
        Savon.should_receive(:client).with(:wsdl => wsdl_uri, :proxy => proxy, :log => false, :logger_level => :info)

        Braspag::Connection.clone.instance.savon_client(wsdl_uri, :logger_level => :info)
      end
    end
  end
end
