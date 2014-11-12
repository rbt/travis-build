require 'core_ext/hash/compact'
require 'travis/shell/generator'

module Travis
  module Shell
    class Generator
      class Bash < Shell::Generator
        require 'travis/shell/generator/bash/cmd'
        require 'travis/shell/generator/bash/helpers'

        include Helpers

        def handle_cmd(code, options = {})
          options = options.compact
          if options.empty?
            handle_raw(code)
          else
            [Cmd.new(code, options).to_bash]
          end
        end

        def handle_echo(message = '', options = {})
          # lines = message.include?("\n") ? message.split("\n") : [message]
          # lines.map do |line|
            # message = %( -e "#{ansi(line, options.delete(:ansi))}") unless message.empty?
            message = ansi(message, options.delete(:ansi)) if options[:ansi]
            message = %( -e #{escape(message)}) # unless message.empty?
            handle_cmd("echo#{message}", options)
          # end
        end

        def handle_newline(options = {})
          handle_cmd('echo')
        end

        def handle_export(data, options = {})
          key, value, options = handle_secure_vars(*data, options)
          handle_cmd("export #{key}=#{value}", options)
        end
        alias handle_set handle_export

        def handle_cd(path, options = {})
          if options[:stack]
            cmd = path == :back ? 'popd' : "pushd #{path}"
            cmd = "#{cmd} &> /dev/null"
          else
            cmd = path == :back ? 'cd -' : "cd #{path}"
          end
          handle_cmd(cmd, options)
        end

        def handle_file(data, options = {})
          path, content = *data
          cmd = ['echo', escape(content)]
          cmd << '| base64 --decode' if options.delete(:decode)
          cmd << (options.delete(:append) ? '>>' : '>')
          cmd << path
          handle_cmd(cmd.join(' '), options)
        end

        def handle_mkdir(path, options = {})
          opts = []
          opts << 'p' if options.delete(:recursive)
          opts = opts.any? ? "-#{opts.join}" : nil
          handle_cmd(['mkdir', opts, path].compact.join(' '), options)
        end

        def handle_chmod(data, options = {})
          mode, path = *data
          opts = []
          opts << 'R' if options.delete(:recursive)
          opts = opts.any? ? "-#{opts.join}" : nil
          cmd = ['chmod', opts, mode, path].compact.join(' ')
          handle_cmd(cmd, options)
        end

        def handle_chown(data, options = {})
          owner, path = *data
          opts = []
          opts << 'R' if options.delete(:recursive)
          opts = opts.any? ? "-#{opts.join}" : nil
          cmd = ['chown', opts, owner, path].compact.join(' ')
          handle_cmd(cmd, options)
        end

        def handle_cp(data, options = {})
          source, target = *data
          opts = []
          opts << 'r' if options.delete(:recursive)
          opts = opts.any? ? "-#{opts.join}" : nil
          cmd = ['cp', opts, source, target].compact.join(' ')
          handle_cmd(cmd, options)
        end

        def handle_mv(data, options = {})
          source, target = *data
          cmd = ['mv', source, target].compact.join(' ')
          handle_cmd(cmd, options)
        end

        def handle_rm(path, options = {})
          opts = []
          opts << 'r' if options.delete(:recursive)
          opts << 'f' if options.delete(:force)
          opts = opts.any? ? "-#{opts.join}" : nil
          cmd = ['rm', opts, path].compact.join(' ')
          handle_cmd(cmd, options)
        end

        def handle_fold(name, cmds, options = {})
          with_margin do
            lines = ["travis_fold start #{name}"]
            lines << handle(cmds)
            lines << "travis_fold end #{name}"
            lines
          end
        end

        def handle_if(condition, *branches)
          options = branches.last.is_a?(Hash) ? branches.pop : {}
          with_margin do
            condition = "[[ #{condition} ]]" unless options.delete(:raw)
            lines = ["if #{condition}; then"]
            lines += branches.map { |branch| handle(branch) }
            lines << 'fi'
            lines
          end
        end

        def handle_then(cmds)
          handle(cmds)
        end

        def handle_elif(condition, cmds)
          lines = ["elif [[ #{condition} ]]; then"]
          lines += handle(cmds)
          lines
        end

        def handle_else(cmds)
          ['else', handle(cmds)]
        end

        private

          def handle_secure_vars(key, value, options)
            if options[:echo] && options.delete(:secure)
              options[:echo] = "export #{key}=[secure]"
              value.untaint
            end
            [key, value, options]
          end
      end
    end
  end
end