module Keepr
  module Validators
    class PostingValidator < ActiveModel::Validator
      def validate(record)
        account_ids = record.keepr_postings.select(:keepr_account_id).distinct.pluck(:keepr_account_id)
        if account_ids.length < 2
          record.errors.add :base, :account_missing
          return
        end

        total_amount = record.keepr_postings.sum(:amount)
        record.errors.add :base, :amount_mismatch unless total_amount.zero?
      end
    end
  end
end
