if defined?(RSpec)
  RSpec.shared_examples 'a Samvera::NestingIndexer::Adapter' do
    let(:required_parameters_extractor) { ->(method) { method.parameters.select { |type, kwarg| type == :keyreq }.map(&:last) } }
    let(:block_parameter_extracter) { ->(method) { method.parameters.select { |type, kwarg| type == :block }.map(&:last) } }

    describe '.find_preservation_document_by' do
      subject { described_class.method(:find_preservation_document_by) }

      it 'requires the :id keyword (and no other)' do
        expect(required_parameters_extractor.call(subject)).to eq([:id])
      end

      it 'does not expect a block' do
        expect(block_parameter_extracter.call(subject)).to be_empty
      end
    end
    describe '.find_index_document_by' do
      subject { described_class.method(:find_index_document_by) }

      it 'requires the :id keyword (and no other)' do
        expect(required_parameters_extractor.call(subject)).to eq([:id])
      end

      it 'does not expect a block' do
        expect(block_parameter_extracter.call(subject)).to be_empty
      end
    end
    describe '.each_preservation_document' do
      subject { described_class.method(:each_preservation_document) }

      it 'requires no keywords' do
        expect(required_parameters_extractor.call(subject)).to eq([])
      end

      it 'expects a block' do
        expect(block_parameter_extracter.call(subject)).to be_present
      end
    end
    describe '.each_child_document_of' do
      subject { described_class.method(:each_child_document_of) }

      it 'requires no keywords' do
        expect(required_parameters_extractor.call(subject)).to eq([])
      end

      it 'expects a block' do
        expect(block_parameter_extracter.call(subject)).to be_present
      end
    end
    describe '.write_document_attributes_to_index_layer' do
    end
  end
end
