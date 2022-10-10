# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Groups::CreateBatchService, type: :service do
  subject(:create_batch_service) do
    described_class.call(
      billable_metric: billable_metric,
      group_params: group_params,
    )
  end

  let(:billable_metric) { create(:billable_metric) }

  context 'when format is not valid' do
    let(:group_params) do
      { "invalid": 'region', "values": %w[usa] }
    end

    it 'returns an error' do
      result = create_batch_service

      aggregate_failures do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:group]).to eq(['invalid_format'])
      end
    end
  end

  context 'when three dimensions' do
    let(:group_params) do
      {
        key: 'region',
        values: [
          {
            name: 'Europe',
            key: 'cloud',
            values: [
              name: 'AWS',
              key: 'country',
              values: %w[France],
            ],
          },
        ],
      }
    end

    it 'returns an error' do
      result = create_batch_service

      aggregate_failures do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:group]).to eq(['invalid_format'])
      end
    end
  end

  context 'with one dimension' do
    let(:group_params) do
      { "key": 'region', "values": %w[usa europe] }
    end

    it 'creates expected groups' do
      expect { create_batch_service }.to change(Group, :count).by(2)

      expect(billable_metric.reload.groups.pluck(:key, :value))
        .to match_array([%w[region usa], %w[region europe]])
    end
  end

  context 'with two dimensions' do
    let(:group_params) do
      {
        "key": 'cloud',
        "values": [
          {
            "name": 'AWS',
            "key": 'region',
            "values": %w[usa europe],
          },
          {
            "name": 'Google',
            "key": 'region',
            "values": %w[usa],
          },
        ],
      }
    end

    it 'creates expected groups' do
      expect { create_batch_service }.to change(Group, :count).by(5)

      groups = billable_metric.reload.groups
      aws = groups.find_by(key: 'cloud', value: 'AWS')
      expect(aws.children.pluck(:key, :value)).to match_array([%w[region usa], %w[region europe]])

      google = groups.find_by(key: 'cloud', value: 'Google')
      expect(google.children.pluck(:key, :value)).to eq([%w[region usa]])
    end
  end
end
