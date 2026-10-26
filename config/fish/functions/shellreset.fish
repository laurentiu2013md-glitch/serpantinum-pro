function shellreset --description 'Restore the complete saved shell setup with automatic backups'
    set -l reset_command (command -s shellreset)
    if test -z "$reset_command"
        printf 'shellreset: install the Serpantinum Pro command-line tools first.\n' >&2
        return 1
    end
    "$reset_command" $argv
end
