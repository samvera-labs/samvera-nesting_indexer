if defined?(RSpec)
  RSpec.shared_examples 'a Samvera::NestingIndexer::Adapter' do
    let(:required_keyword_parameters) { ->(method) { method.parameters.select { |type, kwarg| type == :keyreq }.map(&:last) } }
    let(:required_parameters) { ->(method) { method.parameters.select { |type, kwarg| type == :keyreq || type == :req }.map(&:last) } }
    let(:block_parameter_extracter) { ->(method) { method.parameters.select { |type, kwarg| type == :block }.map(&:last) } }

    describe '.find_preservation_document_by' do
      subject { described_class.method(:find_preservation_document_by) }

      it 'requires the :id  keyword (and does not require any others)' do
        expect(required_keyword_parameters.call(subject)).to eq([:id])
      end

      it 'does not require any other parameters (besides :id)' do
        expect(required_parameters.call(subject)).to eq(required_keyword_parameters.call(subject))
      end

      it 'does not expect a block' do
        expect(block_parameter_extracter.call(subject)).to be_empty
      end
    end
    describe '.find_index_document_by' do
      subject { described_class.method(:find_index_document_by) }

      it 'requires the :id  keyword (and does not require any others)' do
        expect(required_keyword_parameters.call(subject)).to eq([:id])
      end

      it 'does not require any other parameters (besides :id)' do
        expect(required_parameters.call(subject)).to eq(required_keyword_parameters.call(subject))
      end

      it 'does not expect a block' do
        expect(block_parameter_extracter.call(subject)).to be_empty
      end
    end
    describe '.each_preservation_document' do
      subject { described_class.method(:each_preservation_document) }

      it 'requires no keywords' do
        expect(required_keyword_parameters.call(subject)).to eq([])
      end

      it 'does not require any parameters' do
        expect(required_parameters.call(subject)).to eq(required_keyword_parameters.call(subject))
      end

      it 'expects a block' do
        expect(block_parameter_extracter.call(subject)).to be_present
      end
    end
    describe '.each_child_document_of' do
      subject { described_class.method(:each_child_document_of) }

      it 'requires the :document keyword (and does not require any others)' do
        expect(required_keyword_parameters.call(subject)).to eq([:document])
      end

      it 'does not require any other parameters (besides :document)' do
        expect(required_parameters.call(subject)).to eq(required_keyword_parameters.call(subject))
      end

      it 'expects a block' do
        expect(block_parameter_extracter.call(subject)).to be_present
      end
    end
    describe '.write_document_attributes_to_index_layer' do
      subject { described_class.method(:write_document_attributes_to_index_layer) }

      it 'requires the :attributes keyword (and does not require any others)' do
        expect(required_keyword_parameters.call(subject)).to eq([:attributes])
      end

      it 'does not require any other parameters (besides :attributes)' do
        expect(required_parameters.call(subject)).to eq(required_keyword_parameters.call(subject))
      end

      it 'requires a single un-named parameter' do
        expect(required_parameters.call(subject).size).to eq(1)
      end

      it 'does not expect a block' do
        expect(block_parameter_extracter.call(subject)).to be_empty
      end
    end
  end
end
