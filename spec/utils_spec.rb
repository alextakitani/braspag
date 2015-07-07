require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Braspag::Utils do
  describe ".convert_decimal_to_string" do
    it "should convert decimal to string with comma as decimal separator" do
      Braspag::Utils.convert_decimal_to_string(10).should == "10,00"
      Braspag::Utils.convert_decimal_to_string(1).should == "1,00"
      Braspag::Utils.convert_decimal_to_string(0.1).should == "0,10"
      Braspag::Utils.convert_decimal_to_string(0.01).should == "0,01"
      Braspag::Utils.convert_decimal_to_string(9.99999).should == "10,00" # round up
      Braspag::Utils.convert_decimal_to_string(10.9).should == "10,90"
      Braspag::Utils.convert_decimal_to_string(9.1111).should == "9,11"
    end
  end

  describe ".convert_to_map" do
    let(:document) do
      <<-XML
      <root>
        <foo>blabla</foo>
        <bar>bleble</bar>
        <baz></baz>
      </root>
      XML
    end

    let(:namespaced_document) do
      <<-XML
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
      XML
    end

    context "basic document and keys" do
      it "returns a Hash" do
        keys = { :foo => nil, :meu_elemento => "bar", :outro_elemento => "baz" }
        expected = { :foo => "blabla", :meu_elemento => "bleble", :outro_elemento => nil }

        expect(Braspag::Utils::convert_to_map(document, keys)).to eq(expected)
      end
    end

    context "keys with a Proc" do
      it "returns a Hash" do
        proc = Proc.new { "value returned by Proc" }

        keys = { :foo => proc, :meu_elemento => "bar", :outro_elemento => "baz" }
        expected = { :foo => "value returned by Proc", :meu_elemento => "bleble", :outro_elemento => nil }

        expect(Braspag::Utils::convert_to_map(document, keys)).to eq(expected)
      end
    end

    context "when document contains namespaces" do
      it "finds the correct Hash values" do
        keys = {
          holder: "CardHolder",
          card_number: "CardNumber",
          expiration: "CardExpiration",
          masked_card_number: "MaskedCardNumber"
        }

        expected = {
          :holder => "TESTE HOLDER",
          :expiration => "12/2021",
          :card_number => "0000000000000001",
          :masked_card_number =>  "000000******0001"
        }

        expect(Braspag::Utils.convert_to_map(namespaced_document, keys)).to eq(expected)
      end
    end
  end
end
