# encoding: utf-8

module RuboCop
  module Cop
    module Style
      # This cop looks for uses of Perl-style global variables.
      class SpecialGlobalVars < Cop
        include ConfigurableEnforcedStyle

        MSG_BOTH = 'Prefer `%s` from the stdlib \'English\' module, ' \
        'or `%s` over `%s`.'
        MSG_ENGLISH = 'Prefer `%s` from the stdlib \'English\' module ' \
        'over `%s`.'
        MSG_REGULAR = 'Prefer `%s` over `%s`.'

        ENGLISH_VARS = {
          :$: => [:$LOAD_PATH],
          :$" => [:$LOADED_FEATURES],
          :$0 => [:$PROGRAM_NAME],
          :$! => [:$ERROR_INFO],
          :$@ => [:$ERROR_POSITION],
          :$; => [:$FIELD_SEPARATOR, :$FS],
          :$, => [:$OUTPUT_FIELD_SEPARATOR, :$OFS],
          :$/ => [:$INPUT_RECORD_SEPARATOR, :$RS],
          :$\ => [:$OUTPUT_RECORD_SEPARATOR, :$ORS],
          :$. => [:$INPUT_LINE_NUMBER, :$NR],
          :$_ => [:$LAST_READ_LINE],
          :$> => [:$DEFAULT_OUTPUT],
          :$< => [:$DEFAULT_INPUT],
          :$$ => [:$PROCESS_ID, :$PID],
          :$? => [:$CHILD_STATUS],
          :$~ => [:$LAST_MATCH_INFO],
          :$= => [:$IGNORECASE],
          :$* => [:$ARGV, :ARGV],
          :$& => [:$MATCH],
          :$` => [:$PREMATCH],
          :$' => [:$POSTMATCH],
          :$+ => [:$LAST_PAREN_MATCH]
        }

        PERL_VARS =
          Hash[ENGLISH_VARS.flat_map { |k, vs| vs.map { |v| [v, [k]] } }]

        ENGLISH_VARS.merge!(
          Hash[ENGLISH_VARS.flat_map { |_, vs| vs.map { |v| [v, [v]] } }])
        PERL_VARS.merge!(
          Hash[PERL_VARS.flat_map { |_, vs| vs.map { |v| [v, [v]] } }])
        ENGLISH_VARS.freeze
        PERL_VARS.freeze

        # Anything *not* in this set is provided by the English library.
        NON_ENGLISH_VARS = Set.new([
                                     :$LOAD_PATH,
                                     :$LOADED_FEATURES,
                                     :$PROGRAM_NAME,
                                     :ARGV
                                   ])

        def on_gvar(node)
          global_var, = *node

          return unless (preferred = preferred_names(global_var))

          if preferred.include?(global_var)
            correct_style_detected
          else
            opposite_style_detected
            add_offense(node, :expression)
          end
        end

        def message(node)
          global_var, = *node

          if style == :use_english_names
            regular, english = ENGLISH_VARS[global_var].partition do |var|
              NON_ENGLISH_VARS.include? var
            end

            # For now, we assume that lists are 2 items or less. Easy grammar!
            regular_msg = regular.join('` or `')
            english_msg = english.join('` or `')

            if regular.length > 0 && english.length > 0
              format(MSG_BOTH, english_msg, regular_msg, global_var)
            elsif regular.length > 0
              format(MSG_REGULAR, regular_msg, global_var)
            elsif english.length > 0
              format(MSG_ENGLISH, english_msg, global_var)
            else
              fail 'Bug in SpecialGlobalVars - global var w/o preferred vars!'
            end
          else
            format(MSG_REGULAR, preferred_names(global_var).first, global_var)
          end
        end

        def autocorrect(node)
          lambda do |corrector|
            global_var, = *node

            while node.parent && node.parent.begin_type? &&
                  node.parent.children.one?
              node = node.parent
            end
            parent_type = node.parent && node.parent.type

            if [:dstr, :xstr, :regexp].include?(parent_type)
              if style == :use_english_names
                corrector.replace(node.loc.expression,
                                  "{#{preferred_names(global_var).first}}")
              else
                corrector.replace(node.loc.expression,
                                  "##{preferred_names(global_var).first}")
              end
            else
              corrector.replace(node.loc.expression,
                                preferred_names(global_var).first.to_s)
            end
          end
        end

        private

        def preferred_names(global)
          if style == :use_english_names
            ENGLISH_VARS[global]
          else
            PERL_VARS[global]
          end
        end
      end
    end
  end
end
