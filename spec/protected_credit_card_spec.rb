require 'spec_helper'

describe Braspag::ProtectedCreditCard do
  let(:braspag_homologation_protected_card_url) { "https://cartaoprotegido.braspag.com.br" }
  let(:braspag_production_protected_card_url) { "https://www.cartaoprotegido.com.br" }
  let(:merchant_id) { "um id qualquer" }

  before do
    @connection = mock(:merchant_id => merchant_id, :protected_card_url => 'https://www.cartaoprotegido.com.br/Services/TestEnvironment', :homologation? => false)
    Braspag::Connection.stub(:instance => @connection)
    Braspag.proxy_address = nil
  end

  describe ".save" do
    let(:params) do
      {
        :customer_name => "W" * 21,
        :holder =>  "Joao Maria Souza",
        :card_number => "9" * 10,
        :expiration => "10/12",
        :order_id => "um order id",
        :request_id => "{D1BBDA27-65B9-4E68-9700-7A834A80BE88}"
      }
    end

    let(:params_with_merchant_id) do
      params.merge!(:merchant_id => merchant_id)
    end

    let(:save_protected_card_url) { "http://braspag.com/bla" }
    let(:savon_double) { double('Savon') }
    let(:logger) { mock(:info => nil) }

    before do
      Braspag.stub(:logger => logger)
      @connection.should_receive(:merchant_id)
    end

    context "with valid params" do
      let(:valid_response_hash) do
        {
          :save_credit_card_response => {
            :save_credit_card_result => {
              :correlation_id => '{D1BBDA27-65B9-4E68-9700-7A834A80BE88}',
              :just_click_key => '{070071E9-1F73-4C85-B1E4-D8040A627DED}',
              :success => true
            }
          }
        }
      end

      let(:response) do
        xml_response = <<-XML
          <?xml version="1.0" encoding="utf-8"?>
          <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
            <soap:Body>
              <SaveCreditCardResponse xmlns="http://www.cartaoprotegido.com.br/WebService/">
                <SaveCreditCardResult>
                  <CorrelationId>{D1BBDA27-65B9-4E68-9700-7A834A80BE88}</CorrelationId>
                  <JustClickKey>{070071E9-1F73-4C85-B1E4-D8040A627DED}</JustClickKey>
                  <Success>true</Success>
                </SaveCreditCardResult>
              </SaveCreditCardResponse>
            </soap:Body>
          </soap:Envelope>
        XML

        double('Response', :to_s => xml_response, :to_hash => valid_response_hash)
      end

      before do
        Braspag::ProtectedCreditCard.should_receive(:protected_card_url)
        Braspag::ProtectedCreditCard.should_receive(:check_protected_card_params)
                           .and_return(true)
        @connection.should_receive(:savon_client).and_return(savon_double)
        savon_double.should_receive(:call).and_return(response)
      end

      it "should return a Hash" do
        @response = Braspag::ProtectedCreditCard.save(params)

        @response.should be_kind_of Hash
        @response.should == {
          :correlation_id => '{D1BBDA27-65B9-4E68-9700-7A834A80BE88}',
          :just_click_key => '{070071E9-1F73-4C85-B1E4-D8040A627DED}',
          :success => true
        }
      end

      it "should log that the save call was performed" do
        Braspag.logger.should_receive(:info).with(%r{\[Braspag\] #save_credit_card, data:})

        Braspag::ProtectedCreditCard.save(params)
      end

      [
        %r{"RequestId"=>"{D1BBDA27-65B9-4E68-9700-7A834A80BE88}"},
        %r{"MerchantKey"=>"um id qualquer"},
        %r{"CustomerName"=>"WWWWWWWWWWWWWWWWWWWWW"},
        %r{"CardHolder"=>"Joao Maria Souza"},
        %r{"CardExpiration"=>"10/12"}
      ].each do |request_param|
        it "should log the request data with the #{request_param} parameter" do
          Braspag.logger.should_receive(:info).with(request_param)

          Braspag::ProtectedCreditCard.save(params)
        end
      end

      it "should log the response received from to the save call" do
        Braspag.logger.should_receive(:info)
        Braspag.logger.should_receive(:info).with(%r{\[Braspag\] #save_credit_card returns:})

        Braspag::ProtectedCreditCard.save(params)
      end

      [
        %r{<CorrelationId>{D1BBDA27-65B9-4E68-9700-7A834A80BE88}</CorrelationId>},
        %r{<JustClickKey>{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}</JustClickKey>},
        %r{<Success>true</Success>}
      ].each do |response_field|
        it "should log the response with the #{response_field} field" do
          Braspag.logger.should_receive(:info).with(response_field)

          Braspag::ProtectedCreditCard.save(params)
        end
      end

      it "should redact the given card number" do
        Braspag.logger.should_receive(:info).with(%r{"CardNumber"=>"\*\*\*\*\*\*\*\*\*\*\*\*9999"})

        Braspag::ProtectedCreditCard.save(params)
      end

      it "should redact the just click key value" do
        Braspag.logger.should_receive(:info).with(%r{<JustClickKey>{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}<\/JustClickKey>})

        Braspag::ProtectedCreditCard.save(params)
      end
    end

    context "with invalid params" do
      let(:invalid_hash) do
        {
          :save_credit_card_response => {
            :save_credit_card_result => {
              :just_click_key => nil,
              :success => false
            }
          }
        }
      end

      let(:response) do
        double('Response', :to_hash => invalid_hash)
      end

      before do
        Braspag::ProtectedCreditCard.should_receive(:check_protected_card_params)
                            .and_return(true)
        Braspag::ProtectedCreditCard.should_receive(:protected_card_url)
                            .and_return(save_protected_card_url)
        @connection.should_receive(:savon_client).and_return(savon_double)
        savon_double.should_receive(:call).and_return(response)

        @response = Braspag::ProtectedCreditCard.save(params)
      end

      it "should return a Hash" do
        @response.should be_kind_of Hash
        @response.should == {
          :just_click_key => nil,
          :success => false
        }
      end
    end
  end

  class SavonClientTest
    attr_accessor :response
    attr_reader :method

    def call(method, options, &block)
      @method  = method
      @options = options

      @response
    end

    def options
      OpenStruct.new(@options || {})
    end
  end

  describe ".get" do
    let(:get_protected_card_url) { "http://braspag/bla" }

    let(:invalid_xml) do
      <<-EOXML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <GetCreditCardResponse xmlns="http://www.cartaoprotegido.com.br/WebService/">
            <GetCreditCardResult>
              <Success>false</Success>
              <CorrelationId xsi:nil="true"/>
              <ErrorReportCollection>
                <ErrorReport>
                  <ErrorCode>720</ErrorCode>
                  <ErrorMessage>Merchant JustClick not found</ErrorMessage>
                </ErrorReport>
              </ErrorReportCollection>
            </GetCreditCardResult>
          </GetCreditCardResponse>
        </soap:Body>
      </soap:Envelope>
      EOXML
    end

    let(:valid_xml) do
      <<-EOXML
      <?xml version="1.0" encoding="utf-8"?>
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <soap:Body>
          <GetCreditCardResponse xmlns="http://www.cartaoprotegido.com.br/WebService/">
            <GetCreditCardResult>
              <Success>true</Success>
              <CorrelationId xsi:nil="true"/>
              <ErrorReportCollection/>
              <CardHolder>TESTE HOLDER</CardHolder>
              <CardNumber>0000000000000001</CardNumber>
              <CardExpiration>12/2021</CardExpiration>
              <MaskedCardNumber>000000******0001</MaskedCardNumber>
            </GetCreditCardResult>
          </GetCreditCardResponse>
        </soap:Body>
      </soap:Envelope>
      EOXML
    end

    let(:logger) { mock(:info => nil) }
    let(:savon_client) { SavonClientTest.new }

    before { Braspag.logger = logger }

    it "should raise an error when just click key is not valid" do
      Braspag::ProtectedCreditCard.should_receive(:valid_just_click_key?)
                         .with("bla")
                         .and_return(false)

      expect {
        Braspag::ProtectedCreditCard.get "bla"
      }.to raise_error(Braspag::InvalidJustClickKey)
    end

    it "should raise an error when Braspag returned an invalid xml as response" do
      Braspag::ProtectedCreditCard.should_receive(:savon_client)
        .and_return(savon_client)

      expect {
        Braspag::ProtectedCreditCard.get("b0b0b0b0-bbbb-4d4d-bd27-f1f1f1ededed")
      }.to raise_error(Braspag::UnknownError)
    end

    it "should return a Hash when Braspag returned a valid xml as response" do
      Braspag::ProtectedCreditCard.should_receive(:protected_card_url)
                         .and_return(get_protected_card_url)

      savon_client.response = valid_xml

      Braspag::ProtectedCreditCard.should_receive(:savon_client)
        .and_return(savon_client)

      response = Braspag::ProtectedCreditCard.get("b0b0b0b0-bbbb-4d4d-bd27-f1f1f1ededed")

      expect(response).to be_kind_of Hash

      expected = {
        :holder => "TESTE HOLDER",
        :expiration => "12/2021",
        :card_number => "0000000000000001",
        :masked_card_number =>  "000000******0001"
      }

      expect(response).to eq(expected)
    end

  end

  describe ".just_click_shop" do
    context "body" do
      let(:params) { {
        :request_id => "123",
        :customer_name => "Joao Silva",
        :order_id => "999",
        :amount => 10.50,
        :payment_method => :redecard,
        :number_installments => 3,
        :payment_type => "test",
        :just_click_key => "{070071E9-1F73-4C85-B1E4-D8040A627DED}",
        :security_code => "123"
      } }

      let(:logger) { mock(:info => nil) }

      before do
        Braspag.stub(:logger => logger)
        @savon_client_test = SavonClientTest.new
        @savon_client_test.response = {:just_click_shop_response => {}}
        @connection.should_receive(:savon_client).with('https://www.cartaoprotegido.com.br/Services/TestEnvironment/CartaoProtegido.asmx?wsdl').and_return(@savon_client_test)
      end

      after :each do
      end

      it "should have RequestId" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['RequestId'].should eq '123'
      end

      it "should have MerchantKey" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['MerchantKey'].should eq 'um id qualquer'
      end

      it "should have CustomerName" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['CustomerName'].should eq 'Joao Silva'
      end

      it "should have OrderId" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['OrderId'].should eq '999'
      end

      it "should have Amount" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['Amount'].should eq "1050"
      end

      it "should have PaymentMethod" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['PaymentMethod'].should eq 20
      end

      it "should have PaymentType" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['PaymentType'].should eq 'test'
      end

      it "should have NumberInstallments" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['NumberInstallments'].should eq 3
      end

      it "should have JustClickKey" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['JustClickKey'].should eq '{070071E9-1F73-4C85-B1E4-D8040A627DED}'
      end

      it "should have SecurityCode" do
        described_class.just_click_shop(params)
        @savon_client_test.options.message['justClickShopRequestWS']['SecurityCode'].should eq '123'
      end

      it "should log the request data and the response body" do
        Braspag.logger.should_receive(:info).with(%r{\[Braspag\] #just_click_shop, data:})
        Braspag.logger.should_receive(:info).with(%r{\[Braspag\] #just_click_shop returns:})

        described_class.just_click_shop(params)
      end

      it "should redact the given security code" do
        Braspag.logger.should_receive(:info).with(%r{"SecurityCode"=>"\*\*\*"})

        described_class.just_click_shop(params)
      end

      it "should redact the given security code" do
        Braspag.logger.should_receive(:info).with(%r{"JustClickKey"=>"{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}"})

        described_class.just_click_shop(params)
      end
    end

    it ".protected_card_url" do
      @connection.stub(:protected_card_url => braspag_homologation_protected_card_url)

      expect(Braspag::ProtectedCreditCard.protected_card_url).to eq("#{braspag_homologation_protected_card_url}/CartaoProtegido.asmx?wsdl")
    end

  end
end
