# frozen_string_literal: true

RSpec.describe Keepr::AccountExport do
  let!(:account_1000) do
    create(:account, kind: :asset, number: 1000, name: 'Kasse')
  end
  let!(:account_1776) do
    create(:account, kind: :liability, number: 1776, name: 'Umsatzsteuer 19 %')
  end
  let!(:account_4920) do
    create(:account, kind: :expense, number: 4920, name: 'Telefon')
  end
  let!(:account_8400) do
    create(:account, kind: :revenue, number: 8400, name: 'Erlöse 19 %')
  end
  let!(:account_9000) do
    create(:account, kind: :forward, number: 9000, name: 'Saldenvorträge Sachkonten')
  end
  let!(:account_10000) do
    create(:account, kind: :creditor, number: 10_000, name: 'Diverse Kreditoren')
  end
  let!(:account_70000) do
    create(:account, kind: :debtor, number: 70_000, name: 'Diverse Debitoren')
  end

  let(:scope) { Keepr::Account.all }

  let(:export) do
    described_class.new(
      scope,
      'Berater' => 1_234_567,
      'Mandant' => 78_901,
      'WJ-Beginn' => Date.new(2016, 1, 1),
      'Bezeichnung' => 'Keepr-Konten'
    ) do
      { 'Sprach-ID' => 'de-DE' }
    end
  end

  describe 'to_s' do
    let(:exportable) { export.to_s }

    def account_lines
      exportable.lines[2..].map { |line| line.encode(Encoding::UTF_8) }
    end

    it 'returns CSV lines' do
      exportable.lines.all? { |line| expect(line).to include(';') }
    end

    it 'includes header data' do
      expect(exportable.lines[0]).to include('1234567;')
      expect(exportable.lines[0]).to include('78901;')
      expect(exportable.lines[0]).to include('"Keepr-Konten";')
    end

    it 'includes all accounts except debtor/creditor' do
      expect(account_lines.count).to eq(5)

      expect(account_lines[0]).to include('1000;')
      expect(account_lines[0]).to include('"Kasse";')

      expect(account_lines[1]).to include('1776;')
      expect(account_lines[1]).to include('"Umsatzsteuer 19 %";')

      expect(account_lines[2]).to include('4920;')
      expect(account_lines[2]).to include('"Telefon";')

      expect(account_lines[3]).to include('8400;')
      expect(account_lines[3]).to include('"Erlöse 19 %";')

      expect(account_lines[4]).to include('9000;')
      expect(account_lines[4]).to include('"Saldenvorträge Sachkonten";')
    end

    it 'includes data from block' do
      expect(account_lines[0]).to include(';"de-DE"')
      expect(account_lines[1]).to include(';"de-DE"')
    end
  end

  describe 'to_file' do
    it 'creates CSV file' do
      Dir.mktmpdir do |dir|
        filename = "#{dir}/EXTF_Kontenbeschriftungen.csv"
        export.to_file(filename)

        expect(File).to exist(filename)
      end
    end
  end
end
