# frozen_string_literal: true

RSpec.describe Keepr::Journal do
  let!(:account_1000) { create(:account, number: 1000, kind: :asset) }
  let!(:account_1200) { create(:account, number: 1200, kind: :asset) }
  let!(:account_1210) { create(:account, number: 1210, kind: :asset) }
  let!(:account_4910) { create(:account, number: 4910, kind: :expense) }
  let!(:account_4920) { create(:account, number: 4920, kind: :expense) }
  let!(:account_1576) { create(:account, number: 1576, kind: :asset) }
  let!(:account_1600) { create(:account, number: 1600, kind: :liability) }
  let(:journal_blueprint) { build(:journal) }

  let :simple_journal do
    described_class.assign_postings(build(:journal), [
      { keepr_account: account_1000, amount: 100.99, side: 'debit' },
      { keepr_account: account_1200, amount: 100.99, side: 'credit' }
    ]
    )
  end

  let :complex_journal do
    described_class.assign_postings(build(:journal), [
      { keepr_account: account_4920, amount: 8.40, side: 'debit' },
      { keepr_account: account_1576, amount: 1.60, side: 'debit' },
      { keepr_account: account_1600, amount: 10.00, side: 'credit' }
    ]
    )
  end

  describe 'initialization' do
    context 'with date missing' do
      it 'sets date to today' do
        expect(described_class.new.date).to eq(Date.current)
      end
    end

    context 'with date given' do
      it 'does not modify the date' do
        old_date = Date.new(2013, 10, 1)
        expect(described_class.new(date: old_date).date).to eq(old_date)
      end
    end
  end

  describe 'validation' do
    it 'successes for valid journals' do
      expect(simple_journal).to be_valid
      expect(complex_journal).to be_valid
    end

    it 'accepts journal with postings marked for destruction' do
      complex_journal.keepr_postings.first.mark_for_destruction
      complex_journal.keepr_postings.build keepr_account: account_4910, amount: 8.4, side: 'debit'

      expect(complex_journal).to be_valid
    end

    it 'fails for journal with only one posting' do
      journal = described_class.assign_postings(journal_blueprint, [{ keepr_account: account_4920, amount: 8.40, side: 'debit' }])
      expect(journal).not_to be_valid
      expect(journal.errors.added?(:base, :account_missing)).to be(true)
    end

    it 'fails for booking the same account twice' do
      journal = described_class.assign_postings(
        journal_blueprint, [
          { keepr_account: account_1000, amount: 10, side: 'debit' },
          { keepr_account: account_1000, amount: 10, side: 'credit' }
        ]
      )

      expect(journal).not_to be_valid
      expect(journal.errors.added?(:base, :account_missing)).to be(true)
    end

    it 'fails for unbalanced journal' do
      journal = described_class.assign_postings(
        journal_blueprint, [
          { keepr_account: account_1000, amount: 10, side: 'debit' },
          { keepr_account: account_1200, amount: 10, side: 'debit' }
        ]
      )

      expect(journal).not_to be_valid
      expect(journal.errors.added?(:base, :amount_mismatch)).to be(true)
    end

    it 'fails for nil amount' do
      journal = described_class.assign_postings(
        journal_blueprint, [
          { keepr_account: account_1000, amount: 10, side: 'debit' },
          { keepr_account: account_1200, amount: nil, side: 'credit' }
        ]
      )

      expect(journal).not_to be_valid
      expect(journal.errors.added?('keepr_postings.amount', :blank)).to be(true)
    end
  end

  describe 'permanent' do
    before do
      simple_journal.update! permanent: true
    end

    it 'does not allow update' do
      expect(simple_journal.update(subject: 'foo')).to be(false)
      expect(simple_journal.errors.added?(:base, :changes_not_allowed)).to be(true)
    end

    it 'does not allow destroy' do
      expect(simple_journal.destroy).to be(false)
      expect(simple_journal.errors.added?(:base, :changes_not_allowed)).to be(true)
    end
  end

  describe 'postings' do
    it 'returns postings' do
      expect(simple_journal.keepr_postings.size).to eq(2)
      expect(complex_journal.keepr_postings.size).to eq(3)
    end

    it 'orders postings' do
      expect(simple_journal.keepr_postings.map(&:side)).to eq(%w[debit credit])
      expect(complex_journal.keepr_postings.map(&:side)).to eq(%w[debit debit credit])
    end
  end

  describe 'credit_postings' do
    it 'returns postings with positive amount' do
      expect(simple_journal.credit_postings.size).to eq(1)
      expect(complex_journal.credit_postings.size).to eq(1)
    end
  end

  describe 'debit_postings' do
    it 'returns postings with negative amount' do
      expect(simple_journal.debit_postings.size).to eq(1)
      expect(complex_journal.debit_postings.size).to eq(2)
    end
  end

  describe 'amount' do
    it 'returns absolute amount' do
      expect(simple_journal.amount).to eq(100.99)
      expect(complex_journal.amount).to eq(10)
    end
  end
end
