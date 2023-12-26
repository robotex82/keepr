# frozen_string_literal: true

FactoryBot.define do
  factory :account, class: Keepr::Account do
    sequence(:number) { |n| n + 10_000 }
    kind { :asset }
    name { 'Foo' }
  end
end
