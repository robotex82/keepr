# frozen_string_literal: true

module Keepr
  class ContactExport
    def initialize(accounts, header_options = {}, &block)
      raise ArgumentError unless block_given?

      @accounts = accounts
      @header_options = header_options
      @block = block
    end

    delegate :to_s, to: :export

    delegate :to_file, to: :export

    private

    def export
      export = Datev::ContactExport.new(@header_options)

      @accounts.reorder(:number).each do |account|
        export << to_datev(account) if account.debtor? || account.creditor?
      end

      export
    end

    def to_datev(account)
      { 'Konto' => account.number }.merge(@block.call(account))
    end
  end
end
