# frozen_string_literal: true

RSpec.describe Keepr::Tax do
  let!(:tax_account) do
    Keepr::Account.create! number: 1776,
                           name: 'Umsatzsteuer 19%',
                           kind: :asset
  end

  let!(:tax) do
    described_class.create! name: 'USt19',
                            description: 'Umsatzsteuer 19%',
                            value: 19.0,
                            keepr_account: tax_account
  end

  let!(:account) do
    Keepr::Account.create! number: 8400,
                           name: 'Erlöse 19% USt',
                           kind: :revenue,
                           keepr_tax: tax
  end

  it 'is direct linked from account' do
    expect(tax.keepr_accounts).to eq([account])
    expect(account.keepr_tax).to eq(tax)
    expect(tax_account.keepr_tax).to be_nil
  end

  it 'is reverse found from account' do
    expect(tax_account.keepr_taxes).to eq([tax])
    expect(account.keepr_taxes).to eq([])
  end

  it 'avoids circular reference' do
    tax.keepr_account = account
    expect(tax).to be_invalid
    expect(tax.errors[:keepr_account_id]).to be_present
  end
end
