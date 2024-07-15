# frozen_string_literal: true

module Keepr
  class Posting < ActiveRecord::Base
    self.table_name = 'keepr_postings'

    SIDE_DEBIT = 'debit'
    SIDE_CREDIT = 'credit'

    belongs_to :keepr_account, class_name: 'Keepr::Account', optional: false, inverse_of: :keepr_postings
    belongs_to :keepr_journal, class_name: 'Keepr::Journal', optional: false, inverse_of: :keepr_postings
    belongs_to :keepr_cost_center, class_name: 'Keepr::CostCenter', inverse_of: :keepr_postings
    belongs_to :accountable, polymorphic: true

    validates :amount, presence: true
    validate :cost_center_validation

    scope :debits, -> { where('amount >= 0') }
    scope :credits, -> { where('amount < 0') }

    def side
      @side || begin
        (raw_amount.negative? ? SIDE_CREDIT : SIDE_DEBIT) if raw_amount
      end
    end

    def side=(value)
      raise ArgumentError unless [SIDE_DEBIT, SIDE_CREDIT].include?(value)

      @side = value
      return unless amount

      self.raw_amount = credit? ? -amount.to_d : amount.to_d
    end

    def debit?
      side == SIDE_DEBIT
    end

    def credit?
      side == SIDE_CREDIT
    end

    def raw_amount
      read_attribute(:amount)
    end

    def raw_amount=(value)
      write_attribute(:amount, value)
    end

    def amount
      raw_amount&.abs
    end

    def amount=(value)
      @side ||= SIDE_DEBIT

      raise ArgumentError, 'Negative amount not allowed!' if value.to_d.negative?

      self.raw_amount = if value.present?
                          credit? ? -value.to_d : value.to_d
                        end
    end

    private

    def cost_center_validation
      return unless keepr_cost_center
      return if keepr_account.profit_and_loss?

      errors.add :keepr_cost_center_id, :allowed_for_expense_or_revenue_only
    end
  end
end
