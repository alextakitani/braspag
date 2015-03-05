require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'ostruct'

describe Braspag::CreditCard do
  let(:braspag_service_url) { "https://homologacao.pagador.com.br" }

  let(:connection) { mock(
    :merchant_id => 'order-id',
    :protected_card_url => 'https://www.cartaoprotegido.com.br/Services/TestEnvironment',
    :homologation? => (environment == 'homologation'),
    :production? => (environment == 'production'),
    braspag_url: braspag_service_url
  ) }

  let(:request) { OpenStruct.new :url => operation_url }
  let(:environment) { 'homologation' }
  let(:response_xml) { nil }
  let(:operation_url) { nil }

  before { Braspag::Connection.stub(:instance => connection) }

  before do
    ::HTTPI::Request.stub(:new).with(operation_url).and_return(request)
    ::HTTPI.stub(:post).with(request).and_return(mock(:body => response_xml))
  end

  describe ".authorize" do
    let(:operation_url) { "#{connection.braspag_url}/webservices/pagador/Pagador.asmx/Authorize" }
    let(:order_id) { 'order-id' }

    let(:params) { {
      :order_id => order_id,
      :customer_name => "W" * 21,
      :amount => "100.00",
      :payment_method => :redecard,
      :holder => "Joao Maria Souza",
      :card_number => "9" * 10,
      :expiration => "10/12",
      :security_code => "123",
      :number_payments => 1,
      :type => 0
    } }


    let(:response_xml) do
      <<-EOXML
      <?xml version="1.0" encoding="utf-8"?>
      <PagadorReturn xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns="https://www.pagador.com.br/webservice/pagador">
        <amount>5</amount>
        <message>Transaction Successful</message>
        <authorisationNumber>733610</authorisationNumber>
        <returnCode>7</returnCode>
        <status>2</status>
        <transactionId>0</transactionId>
      </PagadorReturn>
      EOXML
    end

    it "request the order authorization" do
      Braspag::CreditCard.authorize(params)
      request.body.should == {"merchantId"=>"order-id", "order"=>"", "orderId"=>"order-id", "customerName"=>"WWWWWWWWWWWWWWWWWWWWW", "amount"=>"100,00", "paymentMethod"=>997, "holder"=>"Joao Maria Souza", "cardNumber"=>"9999999999", "expiration"=>"10/12", "securityCode"=>"123", "numberPayments"=>1, "typePayment"=>0}
    end

    it "returns the authorization result" do
      response = Braspag::CreditCard.authorize(params)
      response.should == {
        :amount => "5",
        :message => "Transaction Successful",
        :number => "733610",
        :return_code => "7",
        :status => "2",
        :transaction_id => "0"
      }
    end

    describe "validation" do
      [:order_id, :amount, :payment_method, :customer_name, :holder, :card_number, :expiration,
        :security_code, :number_payments, :type].each do |param|
        it "raises an error when #{param} parameter is missing" do
          params[param] = nil
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::IncompleteParams)
        end
      end

      context "when order id is invalid" do
        before { params[:order_id] = '' }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidOrderId)
        end
      end

      context "when payment method is invalid" do
        before { params[:payment_method] = 'invalid' }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidPaymentMethod)
        end
      end

      context "when customer name is too long" do
        before { params[:customer_name] = 'n' * 256 }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidCustomerName)
        end
      end

      context "when card holder name is too long" do
        before { params[:holder] = 'h' * 101 }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidHolder)
        end
      end

      context "when expiration is in invalid format" do
        before { params[:expiration] = '2011/19/19' }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidExpirationDate)
        end
      end

      context "when security code is too long" do
        before { params[:security_code] = '12345' }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidSecurityCode)
        end
      end

      context "when security code is too short" do
        before { params[:security_code] = '' }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidSecurityCode)
        end
      end

      context "when the number of payments is too high" do
        before { params[:number_payments] = 100 }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidNumberPayments)
        end
      end

      context "when the number of payments is too low" do
        before { params[:number_payments] = 0 }

        it "raises an error" do
          expect { Braspag::CreditCard.authorize(params) }.to raise_error(Braspag::InvalidNumberPayments)
        end
      end
    end
  end

  describe ".capture" do
    let(:operation_url) { "#{connection.braspag_url}/webservices/pagador/Pagador.asmx/Capture" }
    let(:order_id) { "order-id" }

    let(:response_xml) do
      <<-EOXML
        <?xml version="1.0" encoding="utf-8"?>
        <PagadorReturn xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns="https://www.pagador.com.br/webservice/pagador">
          <amount>2</amount>
          <message>Approved</message>
          <returnCode>0</returnCode>
          <status>0</status>
        </PagadorReturn>
      EOXML
    end

    it "requests the order capture" do
      Braspag::CreditCard.capture("order id qualquer")
      request.body.should == {"orderId"=>"order id qualquer", "merchantId"=>"order-id"}
    end

    it "returns the capture result" do
      response = Braspag::CreditCard.capture("order id qualquer")
      response.should == {
        :amount => "2",
        :number => nil,
        :message => "Approved",
        :return_code => "0",
        :status => "0",
        :transaction_id => nil
      }
    end

    context "when the order id is invalid" do
      let(:order_id) { '' }

      it "raises an error" do
        expect { Braspag::CreditCard.capture(order_id) }.to raise_error(Braspag::InvalidOrderId)
      end
    end
  end

  describe ".partial_capture" do
    let(:operation_url) { "#{connection.braspag_url}/webservices/pagador/Pagador.asmx/CapturePartial" }
    let(:order_id) { "order-id" }

    let(:response_xml) do
      <<-EOXML
        <?xml version="1.0" encoding="utf-8"?>
        <PagadorReturn xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns="https://www.pagador.com.br/webservice/pagador">
          <amount>2</amount>
          <message>Approved</message>
          <returnCode>0</returnCode>
          <status>0</status>
        </PagadorReturn>
      EOXML
    end

    it "requests the order partial capture" do
      Braspag::CreditCard.partial_capture(order_id, 10.0)
      request.body.should == {"orderId"=>"order-id", "captureAmount"=>"10,00", "merchantId"=>"order-id"}
    end

    it "returns the partial capture response" do
      response = Braspag::CreditCard.partial_capture(order_id, 10.0)
      response.should == {
        :amount => "2",
        :number => nil,
        :message => "Approved",
        :return_code => "0",
        :status => "0",
        :transaction_id => nil
      }
    end

    context "when the order id is invalid" do
      let(:order_id) { '' }

      it "raises an error" do
        expect { Braspag::CreditCard.partial_capture(order_id, 10.0) }.to raise_error(Braspag::InvalidOrderId)
      end
    end
  end

  describe ".void" do
    let(:operation_url) { "#{connection.braspag_url}/webservices/pagador/Pagador.asmx/VoidTransaction" }
    let(:order_id) { 'order-id' }

    let(:response_xml) do
      <<-EOXML
        <?xml version="1.0" encoding="utf-8"?>
        <PagadorReturn xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns="https://www.pagador.com.br/webservice/pagador">
          <amount>2</amount>
          <message>Approved</message>
          <returnCode>0</returnCode>
          <status>0</status>
        </PagadorReturn>
      EOXML
    end

    it "requests the order cancellation" do
      Braspag::CreditCard.void(order_id)
      request.body.should == {"order"=>"order-id", "merchantId"=>"order-id"}
    end

    it "returns the cancellation response" do
      response = Braspag::CreditCard.void(order_id)
      response.should == {
        :amount => "2",
        :number => nil,
        :message => "Approved",
        :return_code => "0",
        :status => "0",
        :transaction_id => nil
      }
    end

    context "when the order id is invalid" do
      let(:order_id) { '' }

      it "raises an error" do
        expect { Braspag::CreditCard.void(order_id) }.to raise_error(Braspag::InvalidOrderId)
      end
    end
  end

  describe ".info" do
    let(:operation_url) { "#{connection.braspag_url}/pagador/webservice/pedido.asmx/GetDadosCartao" }
    let(:order_id) { 'order-id' }

    let(:response_xml) do
      <<-EOXML
      <DadosCartao xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                   xmlns="http://www.pagador.com.br/">
        <NumeroComprovante>11111</NumeroComprovante>
        <Autenticada>false</Autenticada>
        <NumeroAutorizacao>557593</NumeroAutorizacao>
        <NumeroCartao>345678*****0007</NumeroCartao>
        <NumeroTransacao>101001225645</NumeroTransacao>
      </DadosCartao>
      EOXML
    end

    it "returns the credit card info response" do
      response = Braspag::CreditCard.info(order_id)
      response.should == {
        :checking_number => "11111",
        :certified => "false",
        :autorization_number => "557593",
        :card_number => "345678*****0007",
        :transaction_number => "101001225645"
      }
    end

    context "when in production" do
      let(:environment) { 'production' }
      let(:operation_url) { "#{connection.braspag_url}/webservices/pagador/pedido.asmx/GetDadosCartao" }

      it "hits the production path" do
        Braspag::CreditCard.info(order_id)
      end
    end

    context "when gateway returns a bad response" do
      let(:response_xml) do
        <<-EOXML
        <DadosCartao xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                     xmlns="http://www.pagador.com.br/">
          <NumeroComprovante></NumeroComprovante>
          <Autenticada>false</Autenticada>
          <NumeroAutorizacao>557593</NumeroAutorizacao>
          <NumeroCartao>345678*****0007</NumeroCartao>
          <NumeroTransacao>101001225645</NumeroTransacao>
        </DadosCartao>
        EOXML
      end

      it "raises an error" do
        expect { Braspag::CreditCard.info(order_id) }.to raise_error(Braspag::UnknownError)
      end
    end
  end

  describe ".status" do
    let(:operation_url) { "#{connection.braspag_url}/webservices/pagador/Pagador.asmx/GetDadosPedido" }
    let(:order_id) { 'order-id' }

    let(:response_xml) do
      <<-EOXML
        <?xml version="1.0" encoding="utf-8"?>
        <DadosPedido xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.pagador.com.br/">
          <CodigoAutorizacao>012543   </CodigoAutorizacao>
          <CodigoPagamento>42</CodigoPagamento>
          <FormaPagamento>Redecard Webservice PreAuth</FormaPagamento>
          <NumeroParcelas>1</NumeroParcelas>
          <Status>3</Status>
          <Valor>35.46</Valor>
          <DataPagamento>2/28/2015 12:00:00 AM</DataPagamento>
          <DataPedido>2/28/2015 9:56:35 AM</DataPedido>
          <TransId>0301122</TransId>
        </DadosPedido>
      EOXML
    end

    it "requests the order status" do
      Braspag::CreditCard.status(order_id)
      request.body.should == {"order"=>"order-id", "merchantId"=>"order-id"}
    end

    it "returns the status response" do
      response = Braspag::CreditCard.status(order_id)
      response.should == {
        :authorization_code=>"012543   ",
        :payment_code=>"42",
        :payment_method=>"Redecard Webservice PreAuth",
        :installments=>"1",
        :status=>"3",
        :value=>"35.46",
        :payment_date=>"2/28/2015 12:00:00 AM",
        :order_date=>"2/28/2015 9:56:35 AM",
        :transaction_id=>"0301122",
        :error_code=>nil,
        :error_message=>nil
      }
    end

    context "when the order id is invalid" do
      let(:order_id) { '' }

      it "raises an error" do
        expect { Braspag::CreditCard.status(order_id) }.to raise_error(Braspag::InvalidOrderId)
      end
    end
  end

  describe ".save .get .just_click_shop" do
    it "should delegate to ProtectedCreditCard class" do
      Braspag::ProtectedCreditCard.should_receive(:save).with({})
      Braspag::CreditCard.save({})

      Braspag::ProtectedCreditCard.should_receive(:get).with('just_click_key')
      Braspag::CreditCard.get('just_click_key')

      Braspag::ProtectedCreditCard.should_receive(:just_click_shop).with({})
      Braspag::CreditCard.just_click_shop({})
    end
  end
end
