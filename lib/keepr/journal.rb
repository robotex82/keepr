# frozen_string_literal: true

require_relative 'validators/posting_validator'

module Keepr
  class Journal < ActiveRecord::Base
    self.table_name = 'keepr_journals'

    belongs_to :accountable, polymorphic: true

    has_many :keepr_postings,
             class_name: 'Keepr::Posting', foreign_key: 'keepr_journal_id', dependent: :destroy, inverse_of: :keepr_journal

    accepts_nested_attributes_for :keepr_postings, allow_destroy: true, reject_if: :all_blank

    validates :date, presence: true
    validates :number, uniqueness: { allow_blank: true }

    after_initialize :set_defaults
    before_update :check_permanent
    before_destroy :check_permanent

    attr_accessor :update_invocation_allowed

    def self.assign_postings(journal, postings_attributes)
      @journal = journal
      ActiveRecord::Base.transaction do
        @journal.update(keepr_postings_attributes: postings_attributes, update_invocation_allowed: true)
        Validators::PostingValidator.new.validate(@journal)

        if @journal.errors.any?
          @journal.define_singleton_method(:valid?) { false }

          raise ActiveRecord::Rollback
        end
      end

      @journal
    end

    def update(attributes)
      update_invocation_allowed = attributes.delete(:update_invocation_allowed)
      raise 'use `assign_postings` to update journal with validation on postings' if update_invocation_allowed != true && attributes[:keepr_postings_attributes].present?

      super
    end

    def credit_postings
      keepr_postings.credits
    end

    def debit_postings
      keepr_postings.debits
    end

    def amount
      debit_postings.sum(&:amount)
    end

    private

    def set_defaults
      self.date ||= Date.current
    end

    def check_permanent
      return unless permanent_was

      errors.add :base, :changes_not_allowed
      throw :abort
    end
  end
end
