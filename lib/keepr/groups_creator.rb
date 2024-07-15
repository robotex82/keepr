# frozen_string_literal: true

module Keepr
  class GroupsCreator
    def initialize(target, language = :de)
      raise ArgumentError unless %i[balance profit_and_loss].include?(target)
      raise ArgumentError unless %i[de es en].include?(language)

      @target   = target
      @language = language
    end

    def run
      case @target
      when :balance
        load 'asset.txt', target: :asset
        load 'liability.txt', target: :liability
      when :profit_and_loss
        load 'profit_and_loss.txt', target: :profit_and_loss
      end
    end

    private

    def load(filename, options) # rubocop:disable Metrics/AbcSize
      full_filename = File.join(File.dirname(__FILE__), "groups_creator/#{@language}/#{filename}".downcase)
      lines = File.readlines(full_filename)
      last_depth = 0
      parents = []

      lines.each do |line|
        # Count leading spaces to calc hierarchy depth
        depth = line[/\A */].size / 2

        # Remove leading spaces and separate number and name
        number, name = line.lstrip.match(/^(.*?)\s(.+)$/).to_a[1..]

        attributes = options.merge(name:, number:)
        attributes[:is_result] = true if @target == :balance && name == annual_surplus

        if depth.zero?
          parents = []
          group = Keepr::Group.create!(attributes)
        else
          parents.pop if depth <= last_depth
          parents.pop if depth < last_depth
          group = parents.last.children.create!(attributes)
        end
        parents.push(group)

        last_depth = depth
      end
    end

    def annual_surplus
      {
        en: 'Annual surplus / annual deficit',
        es: 'Superávit anual / déficit anual',
        de: 'Jahresüberschuss/Jahresfehlbetrag'
      }[@language]
    end
  end
end
