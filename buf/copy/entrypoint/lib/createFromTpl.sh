#!/bin/sh

# Some of the code was borrowed from the NGINX docker image 
# https://github.com/nginxinc/docker-nginx/blob/master/mainline/debian/20-envsubst-on-templates.sh

set -e

ME=$(basename "$0")

entrypoint_log() {
    echo "$@"
}
auto_envsubst() {
    local template_dir="$(pwd)/env_tpls"
    local suffix=".tpl"
    local output_dir="$(pwd)"
    local filter=""
    local inter_num=1
    
    while getopts "f:o:t:i:s:h" options; do
        case "${options}" in
            h)
            echo "Replaces variables (all or by filter \"${filter}\") in \"${template_dir}/*${suffix}\" files and saves them into files of the same name in the output directory (${output_dir})."
            echo "[-f \"\\\${env_var} \\\${env_var2}\"] - Set variables filter"
            echo "[-o \"${output_dir}\"]- Set output directory for parsed files. Default: STDOUT"
            echo "[-t \"${template_dir}\"] - Set templates directory"
            echo "[-s string ] - String template"
            echo "[-i number ] - Default-1. Sets the number of interactions. Repeatedly replaces variables in files "
   
            echo "----"
            echo "Template file sufix (extension) - ${suffix}"
            echo "Templates directory  -  ${template_dir}"
            echo "Output directory  -  ${output_dir}"
            echo "Designation of variables in  template file - \${variable}"
            return 0
            ;;
            f)
            filter="${OPTARG}"
            ;;
            t)
            template_dir="${OPTARG}"
            ;;
            o)
            output_dir="${OPTARG}"
            ;;
            i)
            inter_num="${OPTARG}"
            ;;
        esac
    done
    
    local template defined_envs relative_path output_path subdir random_name random_output_dir
    defined_envs=$(printf '${%s} ' $(awk "END { for (name in ENVIRON) { print ( name ~ /${filter}/ ) ? name : \"\" } }" < /dev/null ))
    [ -d "$template_dir" ] || return 0
    if [ ! -w "$output_dir" ]; then
        entrypoint_log "$ME: ERROR: $template_dir exists, but $output_dir is not writable"
        return 0
    fi
    
    random_name="$(cat /dev/urandom | tr -dc A-Z-a-z-0-9 | head -n 8 -c 8)"
    random_output_dir="$output_dir/$random_name"
    random_template_dir="$output_dir/${random_name}_tpl"
    mkdir -p "${random_output_dir}"
    mkdir -p "${random_template_dir}"
    c=1
    while [ $c -le $inter_num ]
    do
        find "$template_dir" -follow -type f -name "*$suffix" -print | while read -r template; do
            relative_path="${template#"$template_dir/"}"
            output_path="$random_output_dir/${relative_path%"$suffix"}"
            subdir=$(dirname "$relative_path")
            # create a subdirectory where the template file exists
            mkdir -p "$random_output_dir/$subdir"
            #entrypoint_log "$ME: Running envsubst on $template to $output_path"
            envsubst "$defined_envs" < "$template" > "$output_path"
        done
        rm -r "$random_template_dir"
        mv "$random_output_dir" "$random_template_dir"
        template_dir="$random_template_dir"
        suffix=""
        c=$((c+1))
    done
    mv -t "$output_dir" "$random_template_dir"/* 
    rm -r "$random_template_dir"
}

auto_envsubst "$@"

exit 0
