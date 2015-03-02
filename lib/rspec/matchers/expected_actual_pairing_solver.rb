module RSpec
  module Matchers
    class ExpectedActualPairingSolver
      def initialize(expected, actual, matching_proc)
        @expected_actual_indexes = ExpectedActualIndexes.new(expected.size, actual.size)
        @match_iterator = MatchIterator.new(expected, actual, matching_proc)
      end

      def call
        record_matching_locations

        PairingsMaximizer.new(expected_actual_indexes.expected_locations, expected_actual_indexes.actual_locations).find_best_solution
      end

      protected

      attr_reader :expected_actual_indexes, :match_iterator

      private

      def record_matching_locations
        match_iterator.with_matching_locations do |expected_location, actual_location|
          expected_actual_indexes.record_match(expected_location, actual_location)
        end
      end
    end

    class ExpectedActualIndexes
      def initialize(expected_size, actual_size)
        @expected_index = MatchLocations.new(expected_size)
        @actual_index = MatchLocations.new(actual_size)
      end

      def record_match(expected_location, actual_location)
        expected_index.record_match(expected_location, actual_location)
        actual_index.record_match(actual_location, expected_location)
      end

      def expected_locations
        expected_index.locations
      end

      def actual_locations
        actual_index.locations
      end

      protected

      attr_reader :expected_index, :actual_index
    end


    class MatchIterator
      def initialize(expected, actual, matching_proc)
        @expected = expected
        @actual = actual
        @matching_proc = matching_proc
      end

      def with_matching_locations(&blk)
        expected.each_with_index do |expected_value, expected_location|
          actual.each_with_index do |actual_value, actual_location|
            if matching_proc.call(expected_value, actual_value)
              blk.call(expected_location, actual_location)
            end
          end
        end
      end

      protected

      attr_reader :expected, :actual, :matching_proc
    end

    class MatchLocations
      attr_reader :locations

      def initialize(size)
        @locations = Hash[Array.new(size) { |index| [index, []] }]
      end

      def record_match(own_index, other_index)
        locations[own_index] << other_index
      end
    end


  end
end
