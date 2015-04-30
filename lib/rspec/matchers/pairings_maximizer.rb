RSpec::Support.require_rspec_matchers "expected_actual_pairing_solver"

module RSpec
  module Matchers
    class PairingsMaximizer
      attr_reader :expected_to_actual_matched_indices, :actual_to_expected_matched_indices, :solution

      def initialize(expected_to_actual_matched_indices, actual_to_expected_matched_indices)
        @expected_to_actual_matched_indices = expected_to_actual_matched_indices
        @actual_to_expected_matched_indices = actual_to_expected_matched_indices

        unmatched_expected_indices, indeterminate_expected_indices =
          categorize_indices(expected_to_actual_matched_indices, actual_to_expected_matched_indices)

        unmatched_actual_indices, indeterminate_actual_indices =
          categorize_indices(actual_to_expected_matched_indices, expected_to_actual_matched_indices)

        @solution = Solution.new(unmatched_expected_indices, unmatched_actual_indices,
                                 indeterminate_expected_indices, indeterminate_actual_indices)
      end

      def find_best_solution
        return solution if solution.candidate?
        best_solution_so_far = NullSolution

        expected_index = solution.indeterminate_expected_indices.first
        actuals = expected_to_actual_matched_indices[expected_index]

        actuals.each do |actual_index|
          solution = best_solution_for_pairing(expected_index, actual_index)
          return solution if solution.ideal?
          best_solution_so_far = solution if best_solution_so_far.worse_than?(solution)
        end

        best_solution_so_far
      end

      private

      # @private
      # Starting solution that is worse than any other real solution.
      NullSolution = Class.new do
        def self.worse_than?(_other)
          true
        end
      end

      def categorize_indices(indices_to_categorize, other_indices)
        unmatched = []
        indeterminate = []

        indices_to_categorize.each_pair do |index, matches|
          if matches.empty?
            unmatched << index
          elsif !reciprocal_single_match?(matches, index, other_indices)
            indeterminate << index
          end
        end

        return unmatched, indeterminate
      end

      def reciprocal_single_match?(matches, index, other_list)
        return false unless matches.one?
        other_list[matches.first] == [index]
      end

      def best_solution_for_pairing(expected_index, actual_index)
        modified_expecteds = apply_pairing_to(
          solution.indeterminate_expected_indices,
          expected_to_actual_matched_indices, actual_index)

        modified_expecteds.delete(expected_index)

        modified_actuals = apply_pairing_to(
          solution.indeterminate_actual_indices,
          actual_to_expected_matched_indices, expected_index)

        modified_actuals.delete(actual_index)

        solution + self.class.new(modified_expecteds, modified_actuals).find_best_solution
      end

      def apply_pairing_to(indeterminates, original_matches, other_list_index)
        indeterminates.inject({}) do |accum, index|
          accum[index] = original_matches[index] - [other_list_index]
          accum
        end
      end
      Solution = Struct.new(:unmatched_expected_indices, :unmatched_actual_indices,
                            :indeterminate_expected_indices, :indeterminate_actual_indices) do
        def worse_than?(other)
          unmatched_item_count > other.unmatched_item_count
        end

        def candidate?
          indeterminate_expected_indices.empty? &&
            indeterminate_actual_indices.empty?
        end

        def ideal?
          candidate? && (
          unmatched_expected_indices.empty? ||
            unmatched_actual_indices.empty?
          )
        end

        def unmatched_item_count
          unmatched_expected_indices.count + unmatched_actual_indices.count
        end

        def +(derived_candidate_solution)
          self.class.new(
            unmatched_expected_indices + derived_candidate_solution.unmatched_expected_indices,
            unmatched_actual_indices + derived_candidate_solution.unmatched_actual_indices,
            # Ignore the indeterminate indices: by the time we get here,
            # we've dealt with all indeterminates.
            [], []
          )
        end
      end
    end
  end
end
