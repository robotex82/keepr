# frozen_string_literal: true

RSpec.describe Keepr::Account, type: :model do
  let!(:account_1000) { create(:account, number: 1000) }
  let!(:account_1200) { create(:account, number: 1200) }
  let(:journal) { create(:journal) }
  let!(:result_group) { create(:group, target: :liability, is_result: true) }
  let!(:liability_group) { create(:group, target: :liability) }
  let!(:asset_group) { create(:group, target: :asset) }

  let(:journal_attributes) do
    [
      { date: Date.yesterday, permanent: true, postings: [{ account: account_1000, amount: 20, side: 'debit' }, { account: account_1200, amount: 20, side: 'credit' }] },
      { date: Date.yesterday, postings: [{ account: account_1000, amount: 10, side: 'credit' }, { account: account_1200, amount: 10, side: 'debit' }] },
      { date: Date.current, postings: [{ account: account_1000, amount: 200, side: 'debit' }, { account: account_1200, amount: 200, side: 'credit' }] },
      { date: Date.current, postings: [{ account: account_1000, amount: 100, side: 'credit' }, { account: account_1200, amount: 100, side: 'debit' }] }
    ]
  end

  before do
    journal_attributes.each do |entry|
      Keepr::Journal.create!(date: entry[:date], permanent: entry[:permanent] || false,
                             keepr_postings_attributes: entry[:postings].map { |p| { keepr_account: p[:account], amount: p[:amount], side: p[:side] } }
      )
    end
  end

  describe 'Keepr::Account' do
    context 'when formatting number as string' do
      it 'returns number with leading zeros for low values' do
        account = described_class.new(number: 999)
        expect(account.number_as_string).to eq('0999')
      end

      it 'returns number unchanged for high values' do
        account = described_class.new(number: 70_000)
        expect(account.number_as_string).to eq('70000')
      end

      it 'formats correctly with name' do
        account = described_class.new(number: 27, name: 'Software')
        expect(account.to_s).to eq('0027 (Software)')
      end
    end

    context 'with validations' do
      it 'does not allow assigning to result group' do
        account = build(:account, keepr_group: result_group)
        expect(account).not_to be_valid
        expect(account.errors.added?(:keepr_group_id, :no_group_allowed_for_result)).to be(true)
      end

      it 'does not allow assigning asset account to liability group' do
        account = build(:account, kind: :asset, keepr_group: liability_group)
        expect(account).not_to be_valid
        expect(account.errors.added?(:kind, :group_mismatch)).to be(true)
      end

      it 'does not allow assigning liability account to asset group' do
        account = build(:account, kind: :liability, keepr_group: asset_group)
        expect(account).not_to be_valid
        expect(account.errors.added?(:kind, :group_mismatch)).to be(true)
      end

      it 'does not allow assigning forward account to asset group' do
        account = build(:account, kind: :forward, keepr_group: asset_group)
        expect(account).not_to be_valid
        expect(account.errors.added?(:kind, :group_conflict)).to be(true)
      end

      it 'allows target match' do
        account = build(:account, kind: :asset, keepr_group: asset_group)
        expect(account).to be_valid
      end
    end

    context 'when calculating balance' do
      it 'calculates total' do
        expect(account_1000.balance).to eq(110)
        expect(account_1200.balance).to eq(-110)
      end

      it 'calculates total for a given date (including)' do
        expect(account_1000.balance(Date.current)).to eq(110)
        expect(account_1200.balance(Date.current)).to eq(-110)
      end

      it 'calculates total for a given date (excluding)' do
        expect(account_1000.balance(Date.yesterday)).to eq(10)
        expect(account_1200.balance(Date.yesterday)).to eq(-10)
      end

      it 'calculates total for Range' do
        expect(account_1000.balance(Date.yesterday...Date.current)).to eq(110)
        expect(account_1200.balance(Date.yesterday...Date.current)).to eq(-110)
        expect(account_1000.balance(Date.current...Date.tomorrow)).to eq(100)
        expect(account_1200.balance(Date.current...Date.tomorrow)).to eq(-100)
      end

      it 'raises error for invalid param' do
        expect { account_1000.balance(0) }.to raise_error(ArgumentError)
      end
    end

    context 'with_sums' do
      it 'works without params' do
        account1, account2 = described_class.with_sums

        expect(account1.number).to eq(1000)
        expect(account1.balance).to eq(110)
        expect(account2.number).to eq(1200)
        expect(account2.balance).to eq(-110)
      end

      context 'with date option' do
        it 'works with Date' do
          account1, account2 = described_class.with_sums(date: Date.yesterday)

          expect(account1.number).to eq(1000)
          expect(account1.sum_amount).to eq(10)
          expect(account2.number).to eq(1200)
          expect(account2.sum_amount).to eq(-10)
        end

        it 'works with Range' do
          account1, account2 = described_class.with_sums(date: Date.current..Date.tomorrow)

          expect(account1.number).to eq(1000)
          expect(account1.sum_amount).to eq(100)
          expect(account2.number).to eq(1200)
          expect(account2.sum_amount).to eq(-100)
        end

        it 'raises error for other class' do
          expect { described_class.with_sums(date: Time.current) }.to raise_error(ArgumentError)
          expect { described_class.with_sums(date: :foo) }.to raise_error(ArgumentError)
        end
      end

      context 'with permanent_only option' do
        it 'filters the permanent journals' do
          account1, account2 = described_class.with_sums(permanent_only: true)

          expect(account1.number).to eq(1000)
          expect(account1.sum_amount).to eq(20)
          expect(account2.number).to eq(1200)
          expect(account2.sum_amount).to eq(-20)
        end
      end

      context 'with non-hash param' do
        it 'raises error' do
          expect { described_class.with_sums(0) }.to raise_error(ArgumentError)
          expect { described_class.with_sums(:foo) }.to raise_error(ArgumentError)
        end
      end
    end

    context 'with subaccounts' do
      let!(:account_1400) { create(:account, number: 1400) }
      let!(:account_10000) { create(:account, number: 10_000, parent: account_1400) }
      let!(:account_10001) { create(:account, number: 10_001, parent: account_1400) }
      let!(:account_8400) { create(:account, number: 8400) }

      before do
        Keepr::Journal.create!(date: Date.yesterday,
                               keepr_postings_attributes: [{ keepr_account: account_10000, amount: 20, side: 'debit' },
                                                           { keepr_account: account_8400, amount: 20, side: 'credit' }]
                              )
      end

      it 'includes postings from descendant accounts' do
        expect(account_1400.keepr_postings.size).to eq(1)
        expect(account_10000.keepr_postings.size).to eq(1)
      end

      it 'includes postings from descendant accounts with balance' do
        expect(account_1400.reload.balance).to eq(20)
        expect(account_10000.reload.balance).to eq(20)
      end

      it 'includes postings from descendant accounts with date given' do
        expect(account_1400.balance(Date.current)).to eq(20)
        expect(account_10000.balance(Date.current)).to eq(20)
      end

      it 'calculates balance with sums' do
        expect(described_class.with_sums.map { |a| [a.number, a.sum_amount] }).to include([8400, -20], [10_000, 20])
      end

      it 'calculates merged balance' do
        expect(described_class.merged_with_sums.map { |a| [a.number, a.sum_amount] }).to include([1400, 20], [8400, -20])
      end
    end

    context 'with tax' do
      let!(:tax_account) { described_class.create!(number: 1776, name: 'Umsatzsteuer 19%', kind: :asset) }
      let!(:tax) { Keepr::Tax.create!(name: 'USt19', description: 'Umsatzsteuer 19%', value: 19.0, keepr_account: tax_account) }

      it 'links to tax' do
        account = described_class.new(number: 8400, name: 'Erlöse 19% USt', kind: :revenue, keepr_tax: tax)
        expect(account).to be_valid
      end

      it 'avoids circular reference' do
        tax_account.keepr_tax_id = tax.id
        expect(tax_account).to be_invalid
      end
    end
  end
end
