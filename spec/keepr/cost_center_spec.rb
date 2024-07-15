# frozen_string_literal: true

RSpec.describe Keepr::CostCenter do
  let(:cost_center) { create(:cost_center) }
  let(:account_revenue) { create(:account, number: 8400, kind: :revenue) }
  let(:account_expense) { create(:account, number: 4920, kind: :expense) }

  it 'has postings' do
    journal = Keepr::Journal.create!(
      keepr_postings_attributes: [
        { keepr_account: account_revenue, amount: 10, side: 'debit', keepr_cost_center: cost_center },
        { keepr_account: account_expense, amount: 10, side: 'credit', keepr_cost_center: cost_center }
      ]
    )

    expect(cost_center.keepr_postings).to eq(journal.keepr_postings)
  end
end
