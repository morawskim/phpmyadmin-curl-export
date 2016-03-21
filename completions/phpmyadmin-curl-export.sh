# bash completion for the `phpmyadmin-curl-export` command

_phpmyadmin-curl-export_complete()
{
    COMPREPLY=()                        # Array variable storing the possible completions.
    local cur=${COMP_WORDS[COMP_CWORD]} # Pointer to current completion word.
    
    local opts_no_value='--help --compression --add-drop'
    local opts='--auth-type= --http-basic-user= --http-basic-password= --dbname= --host=
                    --phpmyadmin-user= --phpmyadmin-password= --phpmyadmin-server= --save-to='
    opts="$opts $opts_no_value"

    case "$cur" in
         --help|--compression|--add-drop)
            COMPREPLY=( $( compgen -W "$opts_no_value" -- $cur ) )
            ;;
        *)
            COMPREPLY=( $( compgen -W "$opts" -- $cur ) )
            compopt -o nospace;
            ;;
    esac
  
    return 0
}
complete -F _phpmyadmin-curl-export_complete phpmyadmin-curl-export
