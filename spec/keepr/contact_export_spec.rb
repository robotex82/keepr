# frozen_string_literal: true

RSpec.describe Keepr::ContactExport do
  let!(:account_1000)  { create(:account, kind: :asset,     number: 1000, name: 'Kasse') }
  let!(:account_10000) { create(:account, kind: :creditor,  number: 10_000, name: 'Meyer GmbH') }
  let!(:account_70000) { create(:account, kind: :debtor,    number: 70_000, name: 'Schulze AG') }

  let(:scope) { Keepr::Account.all }

  let(:export) do
    described_class.new(
      scope,
      'Berater' => 1_234_567,
      'Mandant' => 78_901,
      'WJ-Beginn' => Date.new(2016, 1, 1),
      'Bezeichnung' => 'Keepr-Kontakte'
    ) do |account|
      { 'Kurzbezeichnung' => account.name }
    end
  end

  describe 'to_s' do
    let(:exportable) { export.to_s }

    def account_lines
      exportable.lines[2..]
    end

    it 'returns CSV lines' do
      exportable.lines.all? { |line| expect(line).to include(';') }
    end

    it 'includes header data' do
      expect(exportable.lines[0]).to include('1234567;')
      expect(exportable.lines[0]).to include('78901;')
      expect(exportable.lines[0]).to include('"Keepr-Kontakte";')
    end

    it 'includes debtor/creditor accounts only' do
      expect(account_lines.count).to eq(2)

      expect(account_lines[0]).to include('10000;')
      expect(account_lines[1]).to include('70000;')
    end

    it 'includes data from block' do
      expect(account_lines[0]).to include('"Meyer GmbH";')
      expect(account_lines[1]).to include('"Schulze AG";')
    end
  end

  describe 'to_file' do
    it 'creates CSV file' do
      Dir.mktmpdir do |dir|
        filename = "#{dir}/EXTF_Stammdaten.csv"
        export.to_file(filename)

        expect(File).to exist(filename)
      end
    end
  end
end
