# frozen_string_literal: true

module Keepr
  class Account < ActiveRecord::Base
    self.table_name = 'keepr_accounts'

    has_ancestry orphan_strategy: :restrict

    enum :kind, %i[asset liability revenue expense forward debtor creditor]

    validates :number, presence: true, uniqueness: true
    validates :name, presence: true
    validate :group_validation
    validate :tax_validation

    has_many :keepr_postings, class_name: 'Keepr::Posting', foreign_key: 'keepr_account_id',
                              dependent: :restrict_with_error, inverse_of: :keepr_account
    has_many :keepr_taxes, class_name: 'Keepr::Tax', foreign_key: 'keepr_account_id',
                           dependent: :restrict_with_error, inverse_of: :keepr_account

    belongs_to :keepr_tax, class_name: 'Keepr::Tax'
    belongs_to :keepr_group, class_name: 'Keepr::Group'
    belongs_to :accountable, polymorphic: true

    default_scope { order(:number) }

    def self.with_sums(options = {})
      raise ArgumentError, 'Options should be a hash' unless options.is_a?(Hash)

      subquery = build_postings_subquery(options)
      select("keepr_accounts.*, (#{subquery.to_sql}) AS sum_amount")
    end

    def self.merged_with_sums(options = {})
      accounts = with_sums(options).to_a
      merge_child_sums_into_parents(accounts)
    end

    def profit_and_loss?
      revenue? || expense?
    end

    def keepr_postings
      Keepr::Posting.joins(:keepr_account).merge(subtree)
    end

    def balance(date = nil)
      scope = build_balance_scope(date)
      scope.sum(:amount)
    end

    def number_as_string
      number.to_s.rjust(4, '0')
    end

    def to_s
      "#{number_as_string} (#{name})"
    end

    private

    def self.build_postings_subquery(options)
      subquery = Keepr::Posting
        .select('SUM(keepr_postings.amount)')
        .joins(:keepr_journal)
        .where('keepr_postings.keepr_account_id = keepr_accounts.id')

      if options[:date]
        subquery = case options[:date]
                   when Date
                     subquery.where('keepr_journals.date <= ?', options[:date])
                   when Range
                     subquery.where(keepr_journals: { date: options[:date].first..options[:date].last })
                   else
                     raise ArgumentError
                   end
      end

      subquery = subquery.where(keepr_journals: { permanent: true }) if options[:permanent_only]
      subquery
    end

    def self.merge_child_sums_into_parents(accounts)
      accounts.each_with_index do |account, index|
        next unless account.parent_id && account.sum_amount

        parent_account = accounts.find { |a| a.id == account.parent_id }
        raise 'Parent account not found' unless parent_account

        parent_account.sum_amount ||= 0
        parent_account.sum_amount += account.sum_amount
        accounts.delete_at(index)
      end
      accounts
    end

    private_class_method :build_postings_subquery, :merge_child_sums_into_parents

    def build_balance_scope(date)
      case date
      when nil
        keepr_postings
      when Date
        keepr_postings.joins(:keepr_journal).where('keepr_journals.date <= ?', date)
      when Range
        keepr_postings.joins(:keepr_journal).where(keepr_journals: { date: date.first..date.last })
      else
        raise ArgumentError, 'Invalid date type'
      end
    end

    def group_validation
      return if keepr_group.blank?

      validate_group_kind
      errors.add(:keepr_group_id, :no_group_allowed_for_result) if keepr_group.is_result
    end

    def validate_group_kind
      case kind
      when 'asset'
        errors.add(:kind, :group_mismatch) unless keepr_group.asset?
      when 'liability'
        errors.add(:kind, :group_mismatch) unless keepr_group.liability?
      when 'revenue', 'expense'
        errors.add(:kind, :group_mismatch) unless keepr_group.profit_and_loss?
      else
        errors.add(:kind, :group_conflict)
      end
    end

    def tax_validation
      errors.add(:keepr_tax_id, :circular_reference) if keepr_tax&.keepr_account == self
    end
  end
end
