RSpec::Support.require_rspec_matchers "pairings_maximizer"

module RSpec
  module Matchers
    module BuiltIn
      # @api private
      # Provides the implementation for `include`.
      # Not intended to be instantiated directly.
      class Include < BaseMatcher
        def initialize(*expected)
          @expected = expected
        end

        # @api private
        # @return [Boolean]
        def matches?(actual)
          @actual = actual
          perform_match(:all?, :all?)
        end

        # @api private
        # @return [Boolean]
        def does_not_match?(actual)
          @actual = actual
          perform_match(:none?, :any?)
        end

        # @api private
        # @return [String]
        def description
          described_items = surface_descriptions_in(expected)
          improve_hash_formatting "include#{to_sentence(described_items)}"
        end

        # @api private
        # @return [String]
        def failure_message
          improve_hash_formatting(super) + invalid_object_message
        end

        # @api private
        # @return [String]
        def failure_message_when_negated
          improve_hash_formatting(super) + invalid_object_message
        end

        # @api private
        # @return [Boolean]
        def diffable?
          true
        end

      private

        def invalid_object_message
          return '' if actual.respond_to?(:include?)
          ", but it does not respond to `include?`"
        end

        def perform_match(predicate, hash_subset_predicate)
          return false unless actual.respond_to?(:include?)

          inclusion_checker = inclusion_checker(hash_subset_predicate)
          if Array === actual
            if predicate == :none?
              inclusion_checker.call(0)
            elsif predicate == :all?
              inclusion_checker.call(expected.size)
            end
          else
            if predicate == :none?
              expected.none? { |expected_item| inclusion_checker.call(expected_item) }
            elsif predicate == :all?
              expected.all? { |expected_item| inclusion_checker.call(expected_item) }
            end
          end
        end

        def inclusion_checker(hash_subset_predicate)
          case actual
            when Array
              ArrayInclusionChecker.new(expected, actual)
            when Hash
              HashInclusionChecker.new(expected, actual, hash_subset_predicate)
            else
              CollectionInclusionChecker.new(expected, actual)
          end
        end

        class ArrayInclusionChecker
          def initialize(expected, actual)
            @expected = expected
            @actual = actual
          end

          def call(expected_matching_item_count)
            unmatched_item_count = ExpectedActualPairingSolver.best_solution(
              expected,
              actual
            ).unmatched_expected_indices.count
            expected.count - unmatched_item_count == expected_matching_item_count
          end

          protected

          attr_reader :expected, :actual
        end

        class HashInclusionChecker
          def initialize(expected, actual, hash_subset_predicate)
            @expected = expected
            @actual = actual
            @hash_subset_predicate = hash_subset_predicate
          end

          def call(expected_item)
            if Hash === expected_item
              expected_item.__send__(hash_subset_predicate) do |(key, value)|
                actual_hash_includes?(key, value)
              end
            else
              actual_hash_has_key?(expected_item)
            end
          end

        protected

          attr_reader :expected, :actual, :hash_subset_predicate

        private

          def actual_hash_includes?(expected_key, expected_value)
            actual_value = actual.fetch(expected_key) { return false }
            values_match?(expected_value, actual_value)
          end

          def actual_hash_has_key?(expected_key)
            # We check `key?` first for perf:
            # `key?` is O(1), but `any?` is O(N).
            actual.key?(expected_key) ||
              actual.keys.any? { |key| values_match?(expected_key, key) }
          end

          def values_match?(expected, actual)
            RSpec::Matchers::Composable.values_match?(expected, actual)
          end
        end

        class CollectionInclusionChecker
          def initialize(expected, actual)
            @expected = expected
            @actual = actual
          end

          def call(expected_item)
            actual_collection_includes?(expected_item)
          end

          protected

          attr_reader :expected, :actual

          private

          def actual_collection_includes?(expected_item)
            return true if actual.include?(expected_item)

            # String lacks an `any?` method...
            return false unless actual.respond_to?(:any?)

            actual.any? { |value| values_match?(expected_item, value) }
          end

          def values_match?(expected, actual)
            RSpec::Matchers::Composable.values_match?(expected, actual)
          end
        end
      end
    end
  end
end
