# encoding: utf-8
# frozen_string_literal: true

module RuboCop
  module Cop
    module Lint
      # This cop checks for a rescued exception that get shadowed by a
      # less specific exception being rescued before a more specific
      # exception is rescued.
      #
      # @example
      # # bad
      # begin
      #   something
      # rescue Exception
      #   handle_exception
      # rescue StandardError
      #   handle_standard_error
      # end
      #
      # #good
      # begin
      #   something
      # rescue StandardError
      #   handle_standard_error
      # rescue Exception
      #   handle_exception
      # end
      class ShadowedException < Cop
        MSG = 'Do not shadow rescued Exceptions'.freeze

        def on_rescue(node)
          return if rescue_modifier?(node)
          _body, *rescues, _else = *node
          rescued_groups = rescues.each_with_object([]) do |group, exceptions|
            rescue_group, = *group

            exceptions << evaluate_exceptions(rescue_group)
          end

          rescue_group_rescues_multiple_levels = rescued_groups.any? do |group|
            !contains_multiple_levels_of_exceptions?(group)
          end

          return if rescue_group_rescues_multiple_levels &&
                    rescued_groups == sort_rescued_groups(rescued_groups)

          add_offense(node, :expression)
        end

        private

        def rescue_modifier?(node)
          node && node.rescue_type? &&
            (node.parent.nil? || !(node.parent.kwbegin_type? ||
             node.parent.ensure_type?))
        end

        def contains_multiple_levels_of_exceptions?(group)
          group.any? do |exception|
            higher_exception = false
            group.each_with_index do |_e, i|
              higher_exception ||= group[i] < exception
            end

            higher_exception
          end
        end

        def evaluate_exceptions(rescue_group)
          if rescue_group
            rescued_exceptions = rescue_group.source.delete(' ').split(',')

            rescued_exceptions.each_with_object([]) do |exception, converted|
              begin
                converted << instance_eval(exception, __FILE__, __LINE__)
              rescue StandardError, ScriptError
                next
              end
            end
          else
            # treat an empty `rescue` as `rescue StandardError`
            [StandardError]
          end
        end

        def sort_rescued_groups(groups)
          groups.sort do |x, y|
            x <=> y || 0
          end
        end
      end
    end
  end
end
