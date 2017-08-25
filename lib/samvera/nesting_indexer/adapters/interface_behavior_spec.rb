if defined?(RSpec)
  RSpec.shared_examples 'a Samvera::NestingIndexer::Adapter' do
    let(:required_keyword_parameters) { ->(method) { method.parameters.select { |type, _kwarg| type == :keyreq }.map(&:last).sort } }
    let(:required_parameters) { ->(method) { method.parameters.select { |type, _kwarg| type == :keyreq || type == :req }.map(&:last).sort } }
    let(:block_parameter_extracter) { ->(method) { method.parameters.select { |type, _kwarg| type == :block }.map(&:last).sort } }

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
    describe '.find_preservation_parent_ids_for' do
      subject { described_class.method(:find_preservation_parent_ids_for) }

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
    describe '.each_perservation_document_id_and_parent_ids' do
      subject { described_class.method(:each_perservation_document_id_and_parent_ids) }

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
        expect(required_keyword_parameters.call(subject)).to eq(%i(ancestors id parent_ids pathnames))
      end

      it 'does not require any other parameters (besides :attributes)' do
        expect(required_parameters.call(subject)).to eq(required_keyword_parameters.call(subject))
      end

      it 'does not expect a block' do
        expect(block_parameter_extracter.call(subject)).to be_empty
      end
    end
  end
end
