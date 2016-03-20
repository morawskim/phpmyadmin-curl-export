#!/bin/sh
#===============================================================================
#
#          FILE: phpmyadmin-curl-export.sh
# 
#         USAGE: phpmyadmin-curl-export.sh
# 
#   DESCRIPTION: Connect to phpMyAdmin and export database to file.
# 
#       OPTIONS: See phpmyadmin-curl-export.sh --help
#  REQUIREMENTS: curl, coreutils, grep
#          BUGS: https://github.com/morawskim/phpmyadmin-curl-export/issues
#         NOTES: ---
#        AUTHOR: Marcin Morawski (marcin@morawskim.pl), 
#  ORGANIZATION: 
#       CREATED: 20.03.2016 09:59
#      REVISION: 1
#===============================================================================

set -o nounset                              # Treat unset variables as an error
set -e                                      # Exit immediately if a command exits with a non-zero status.

http_username=
http_password=
use_http_auth=
save_to=
phpmyadmin_server=
compression='none'
add_drop_statement=
cookie_path='/tmp/phpmyadmin-curl.cookies'
headers_path='/tmp/phpmyadmin-curl.headers'
response_path='/tmp/phpmyadmin-curl.response'

culr_cookie_option="-b $cookie_path -c $cookie_path"
curl_dump_headers_option="-D $headers_path"
curl_save_response_path=$response_path

function parse_arguments()
{
    local save_to_extension='sql'

    for i in "$@"
    do
        case $i in
        --auth-type=*)
            auth_type="${i#*=}"
            shift # past argument=value
            ;;
        --http-basic-user=*)
            http_username="${i#*=}"
            shift # past argument=value
            ;;
        --http-basic-password=*)
            http_password="${i#*=}"
            shift # past argument=value
            ;;
        --dbname=*)
            phpmyadmin_dbname="${i#*=}"
            shift # past argument=value
            ;;
        --host=*)
            phpmyadmin_host="${i#*=}"
            shift # past argument=value
            ;;
        --phpmyadmin-user=*)
            phpmyadmin_user="${i#*=}"
            shift # past argument=value
            ;;
        --phpmyadmin-password=*)
            phpmyadmin_password="${i#*=}"
            shift # past argument=value
            ;;
        --phpmyadmin-server=*)
            phpmyadmin_server="${i#*=}"
            shift # past argument with no value
            ;;
        --save-to=*)
            save_to="${i#*=}"
            shift # past argument with no value
            ;;
        --help)
            phpmyadmin_help
            exit 0
            ;;
        --compression)
            compression='gzip'
            save_to_extension="$save_to_extension.gz"
            ;;
        --add-drop)
            add_drop_statement='1'
            ;;
        *)
            # unknown option
            echo "Unkown option $i" >&2
            exit 1
            ;;
        esac
    done
    
    if [ ${#http_username} -gt 0 -a ${#http_password} -gt 0 ]; then
        use_http_auth="--basic -u $http_username:$http_password"
    fi
    
    if [ -z $save_to ]; then
        save_to=$(date +"%F-$phpmyadmin_dbname.$save_to_extension")
    fi
}

function phpmyadmin_help()
{
    cat <<EOF
Arguments: $0 [--help] [--auth-type=<cookie|basic>] [--http-basic-user=<apache_http_user>] [--http-basic-password=<apache_http_password>] [--phpmyadmin-user=<phpmyadmin_user>] [--phpmyadmin-password=<phpmyadmin_password>] [--phpmyadmin-server=<phpmyadmin_server>] [--dbname=<database>] [--host=<phpmyadmin_host>] [--save-to=<%F-\$dbname.sql>] [--compression] [--add-drop]
       --help: Print help
       --auth-type=<cookie|basic>: Method of authentication to phpMyAdmin 
       --http-basic-user=<apache_http_user>: Username for HTTP basic authentication
       --http-basic-password=<apache_http_password>: Password for HTTP basic authentication
       --phpmyadmin-user=<phpmyadmin_user>: PhpMyAdmin user (used by cookie auth)
       --phpmyadmin-password=<phpmyadmin_password>: PhpMyAdmin password (used by cookie auth)
       --phpmyadmin-server=<phpmyadmin_server>: To which server connect, if phpMyAdmin have more than one server
       --dbname=<database>: Database to be exported
       --host=<phpmyadmin_host>: PhpMyAdmin host
       --save-to=<%F-\$dbname.sql>: Output filename (support for date format controls eg. %F)
       --compression: Enable gzip compression
       --add-drop: Add DROP TABLE / VIEW / PROCEDURE / FUNCTION / EVENT / TRIGGER statement

 Common uses: $0 --auth-type=cookie --dbname=example --phpmyadmin-user=example --phpmyadmin-password=example --host=http://localhost/phpMyAdmin
    exports example database and save in working directory
EOF
}

function phpmyadmin_auth_basic()
{
    curl "$phpmyadmin_host/index.php" \
        -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:45.0) Gecko/20100101 Firefox/45.0' \
        -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
        -H 'Accept-Language: en-US,en;q=0.5' \
        --compressed \
        $use_http_auth \
        -s \
        -k \
        $curl_dump_headers_option \
        $culr_cookie_option \
        -L > $curl_save_response_path

    phpmyadmin_check_response_code "Cant login by auth_basic to $phpmyadmin_host"
}

function phpmyadmin_auth_cookie()
{
    local username=$1
    local password=$2
    local server=$3

    curl "$phpmyadmin_host/index.php" \
        -s -k $curl_dump_headers_option \
        $culr_cookie_option \
        -L > $curl_save_response_path

    phpmyadmin_check_response_code "Cant login by cookie to $phpmyadmin_host"

    local token=$(phpmyadmin_get_token_from_response)

    local post_params="pma_username=$username"
    post_params="$post_params&pma_password=$password"
    post_params="$post_params&server=$server"
    post_params="$post_params&token=$token"

    curl "$phpmyadmin_host/index.php" \
        -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:45.0) Gecko/20100101 Firefox/45.0' \
        -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
        -H 'Accept-Language: en-US,en;q=0.5' \
        --compressed \
        $curl_dump_headers_option \
        -s \
        -L \
        --data $post_params \
        $culr_cookie_option  > $curl_save_response_path

    phpmyadmin_check_response_code "Cant login by cookie to $phpmyadmin_host"
}

function phpmyadmin_get_token_from_response()
{
    echo $(cat $curl_save_response_path | grep link | grep 'phpmyadmin.css.php' | grep -o -E "token=([^\&\'])*" | cut -d= -f2 | head -1)
}

function phpmyadmin_remove_tmp_files()
{
    rm -f $response_path $headers_path $cookie_path
}

function phpmyadmin_check_response_code()
{
    #echo "HTTP/1.1 401 Not Auth" >> $headers_path

    local http_response_code=$(tac $headers_path | grep HTTP | head -1 | cut -f2 -d' ')
    if [ $http_response_code -ge 200 -a $http_response_code -le 299 ]; then
        return 0
    else
        echo "$1">&2
        exit 2
    fi
}

function phpmyadmin_auth()
{
    case $auth_type in
    basic)
        phpmyadmin_auth_basic
        ;;
    cookie)
        phpmyadmin_auth_cookie $phpmyadmin_user $phpmyadmin_password $phpmyadmin_server
        ;;
    *)
        echo "not supported auth type $auth_type" >&2
        exit 1
        ;;
    esac
}

if [ $# -eq 0 ]; then
    phpmyadmin_help
    exit
fi

parse_arguments $@
phpmyadmin_auth

token=$(phpmyadmin_get_token_from_response)

post_params="token=$token"
post_params="$post_params&export_type=server"
post_params="$post_params&export_method=quick"
post_params="$post_params&quick_or_custom=custom"
post_params="$post_params&db_select%5B%5D=$phpmyadmin_dbname"
post_params="$post_params&output_format=sendit"
post_params="$post_params&filename_template=%40SERVER%40"
post_params="$post_params&remember_template=on"
post_params="$post_params&charset_of_file=utf-8"
post_params="$post_params&compression=$compression"
post_params="$post_params&maxsize="
post_params="$post_params&what=sql"
post_params="$post_params&codegen_structure_or_data=data"
post_params="$post_params&codegen_format=0"
post_params="$post_params&excel_null=NULL"
post_params="$post_params&excel_edition=win"
post_params="$post_params&excel_structure_or_data=data"
post_params="$post_params&csv_separator=%2C"
post_params="$post_params&csv_enclosed=%22"
post_params="$post_params&csv_escaped=%22"
post_params="$post_params&csv_terminated=AUTO"
post_params="$post_params&csv_null=NULL"
post_params="$post_params&csv_structure_or_data=data"
post_params="$post_params&odt_structure_or_data=structure_and_data"
post_params="$post_params&odt_comments=something"
post_params="$post_params&odt_columns=something"
post_params="$post_params&odt_null=NULL"
post_params="$post_params&phparray_structure_or_data=data"
post_params="$post_params&mediawiki_structure_or_data=data"
post_params="$post_params&mediawiki_caption=something"
post_params="$post_params&mediawiki_headers=something"
post_params="$post_params&yaml_structure_or_data=data"
post_params="$post_params&htmlword_structure_or_data=structure_and_data"
post_params="$post_params&htmlword_null=NULL"
post_params="$post_params&json_structure_or_data=data"
post_params="$post_params&latex_caption=something"
post_params="$post_params&latex_structure_or_data=structure_and_data"
post_params="$post_params&latex_structure_caption=Structure+of+table+%40TABLE%40"
post_params="$post_params&latex_structure_continued_caption=Structure+of+table+%40TABLE%40+%28continued%29"
post_params="$post_params&latex_structure_label=tab%3A%40TABLE%40-structure"
post_params="$post_params&latex_comments=something"
post_params="$post_params&latex_columns=something"
post_params="$post_params&latex_data_caption=Content+of+table+%40TABLE%40"
post_params="$post_params&latex_data_continued_caption=Content+of+table+%40TABLE%40+%28continued%29"
post_params="$post_params&latex_data_label=tab%3A%40TABLE%40-data"
post_params="$post_params&latex_null=%5Ctextit%7BNULL%7D"
post_params="$post_params&ods_null=NULL"
post_params="$post_params&ods_structure_or_data=data"
post_params="$post_params&pdf_report_title="
post_params="$post_params&pdf_structure_or_data=data"
post_params="$post_params&texytext_structure_or_data=structure_and_data"
post_params="$post_params&texytext_null=NULL"
post_params="$post_params&sql_include_comments=something"
post_params="$post_params&sql_header_comment="
post_params="$post_params&sql_compatibility=NONE"
post_params="$post_params&sql_structure_or_data=structure_and_data"
post_params="$post_params&sql_create_table=something"
post_params="$post_params&sql_create_view=something"
post_params="$post_params&sql_procedure_function=something"
post_params="$post_params&sql_create_trigger=something"
post_params="$post_params&sql_create_table_statements=something"
post_params="$post_params&sql_if_not_exists=something"
post_params="$post_params&sql_auto_increment=something"
post_params="$post_params&sql_backquotes=something"
post_params="$post_params&sql_type=INSERT"
post_params="$post_params&sql_insert_syntax=both"
post_params="$post_params&sql_max_query_size=50000"
post_params="$post_params&sql_hex_for_binary=something"
post_params="$post_params&sql_utc_time=something"

if [ ! -z $add_drop_statement ]; then
    post_params="$post_params&sql_drop_table=something"
fi

if [ ! -z $phpmyadmin_server ]; then
    post_params="$post_params&server=$phpmyadmin_server"
fi

curl "$phpmyadmin_host/export.php" \
    -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:45.0) Gecko/20100101 Firefox/45.0' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
    -H 'Accept-Language: en-US,en;q=0.5' \
    -k \
    $use_http_auth \
    $curl_dump_headers_option \
    -L \
    -s \
    $culr_cookie_option \
    -H 'Connection: keep-alive' \
    -o $save_to \
    --data $post_params
  
phpmyadmin_check_response_code "Cant dump database $phpmyadmin_dbname"

echo "Save dump database to $save_to"
echo 'Remove tmp files...'
phpmyadmin_remove_tmp_files
