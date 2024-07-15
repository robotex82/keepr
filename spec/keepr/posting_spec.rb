# frozen_string_literal: true

RSpec.describe Keepr::Posting do
  let!(:account_1000) { create(:account, number: 1000, kind: :asset) }
  let(:journal) { create(:journal) }

  before do
    allow(journal).to receive(:validate_postings).and_return(true)
  end

  describe 'side/amount' do
    it 'handles empty object' do
      posting = described_class.new
      expect(posting.amount).to be_nil
      expect(posting.side).to be_nil
    end

    it 'sets credit amount' do
      posting = described_class.new(amount: 10, side: 'credit')

      expect(posting).to be_credit
      expect(posting.amount).to eq(10)
      expect(posting.raw_amount).to eq(-10)
    end

    it 'sets debit amount' do
      posting = described_class.new(amount: 10, side: 'debit')

      expect(posting).to be_debit
      expect(posting.amount).to eq(10)
      expect(posting.raw_amount).to eq(10)
    end

    it 'sets side and amount in different steps' do
      posting = described_class.new

      posting.side = 'credit'
      expect(posting).to be_credit
      expect(posting.amount).to be_nil

      posting.amount = 10
      expect(posting).to be_credit
      expect(posting.amount).to eq(10)
    end

    it 'changes to credit' do
      posting = described_class.new(amount: 10, side: 'debit')
      posting.side = 'credit'

      expect(posting).to be_credit
      expect(posting.amount).to eq(10)
    end

    it 'changes to debit' do
      posting = described_class.new(amount: 10, side: 'credit')
      posting.side = 'debit'

      expect(posting).to be_debit
      expect(posting.amount).to eq(10)
    end

    it 'defaults to debit' do
      posting = described_class.new(amount: 10)

      expect(posting).to be_debit
      expect(posting.amount).to eq(10)
    end

    it 'handles string amount' do
      posting = described_class.new(amount: '0.5')

      expect(posting).to be_debit
      expect(posting.amount).to eq(0.5)
    end

    it 'recognizes saved debit posting' do
      posting = described_class.create!(amount: 10, side: 'debit', keepr_account: account_1000, keepr_journal: journal)
      posting.reload

      expect(posting).to be_debit
      expect(posting.amount).to eq(10)
    end

    it 'recognizes saved credit posting' do
      posting = described_class.create!(amount: 10, side: 'credit', keepr_account: account_1000, keepr_journal: journal)
      posting.reload

      expect(posting).to be_credit
      expect(posting.amount).to eq(10)
    end

    it 'fails for negative amount' do
      expect { described_class.new(amount: -10) }.to raise_error(ArgumentError)
    end

    it 'fails for unknown side' do
      expect { described_class.new(side: 'foo') }.to raise_error(ArgumentError)
    end
  end

  describe 'scopes' do
    let!(:debit_posting) { described_class.create!(amount: 10, side: 'debit', keepr_account: account_1000, keepr_journal: journal) }
    let!(:credit_posting) { described_class.create!(amount: 10, side: 'credit', keepr_account: account_1000, keepr_journal: journal) }

    it 'filters by debits and credits' do
      expect(account_1000.keepr_postings.debits).to eq([debit_posting])
      expect(account_1000.keepr_postings.credits).to eq([credit_posting])
    end
  end

  describe 'cost_center handling' do
    let(:cost_center) { create(:cost_center) }
    let(:account_8400) { create(:account, number: 8400, kind: :revenue) }

    it 'allows cost_center for revenue account' do
      posting = described_class.new(keepr_account: account_8400, amount: 100, keepr_cost_center: cost_center, keepr_journal: journal)
      expect(posting).to be_valid
    end

    it 'does not allow cost_center for balance account' do
      posting = described_class.new(keepr_account: account_1000, amount: 100, keepr_cost_center: cost_center, keepr_journal: journal)
      expect(posting).not_to be_valid
    end
  end
end
