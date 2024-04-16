initialize-scene-tests() {
    local $output_dir = $1
    local $scenes_path = $2

    echo "Initializing scene testing."
    rm -rf "$output_dir"
    mkdir -p "$output_dir/reports"

    runSofa="$(ls "$build_dir/bin/runSofa"{,d,_d} 2> /dev/null || true)"
    if [[ -x "$runSofa" ]] || [[ -L "$runSofa" ]]; then
        echo "Found runSofa: $runSofa" | log
    else
        echo "Error: could not find runSofa."
        exit 1
    fi

    touch "$output_dir/reports/successes.txt"
    touch "$output_dir/reports/warnings.txt"
    touch "$output_dir/reports/errors.txt"
    touch "$output_dir/reports/crashes.txt"

    create-directories  $output_dir $scenes_path
    sum-up-scenes  $output_dir $scenes_path
}


list-scenes() {
    local directory="$1"

    scenes_scn="$(/usr/bin/find "$directory" -name '*.scn' | sed -e "s:$directory/::")"
    scenes_scn_grep="scenes_scn_to_filter_out"
    for scene in $scenes_scn; do
        scenes_scn_grep="$scenes_scn_grep"'\|'"${scene%.*}"
    done
    scenes_pyscn="$(/usr/bin/find "$directory" -name '*.pyscn' | sed -e "s:$directory/::" | grep -v "$scenes_scn_grep")"
    scenes_py="$(/usr/bin/find "$directory" -name '*.py' | sed -e "s:$directory/::" | grep -v "$scenes_scn_grep")"

    (echo "$scenes_scn" && echo "$scenes_pyscn" && echo "$scenes_py") | sort | uniq
}


create-directories() {

    local $output_dir = $1
    local $scenes_path = $2

    list-scenes "$scenes_path" > "$output_dir/scenes.txt"
    while read scene; do
        mkdir -p "$output_dir/$scene"
        if [[ "$CI_TYPE" == "Debug" ]]; then
            echo 300 > "$output_dir/$scene/timeout.txt" # Default debug timeout, in seconds
        else
            echo 30 > "$output_dir/$scene/timeout.txt" # Default release timeout, in seconds
        fi
        echo 100 > "$output_dir/$scene/iterations.txt" # Default number of iterations
        echo "$scene" >> "$output_dir/all-scenes.txt"
    done < "$output_dir/scenes.txt"
}

sum-up-scenes() {
      local $output_dir = $1
      local $scenes_path = $2

      local $path = $scenes_path
      grep -f "$output_dir/$path/ignore-patterns.txt" "$output_dir/$path/scenes.txt" > "$output_dir/$path/ignored-scenes.txt" || true
      if [ -s "$output_dir/$path/ignore-patterns.txt" ]; then
          grep -v -f "$output_dir/$path/ignore-patterns.txt" "$output_dir/$path/scenes.txt" > "$output_dir/$path/tested-scenes.txt" || true
      else
          cp  "$output_dir/$path/scenes.txt" "$output_dir/$path/tested-scenes.txt"
      fi

      sed -e "s:^:$path/:" "$output_dir/$path/ignored-scenes.txt" >> "$output_dir/all-ignored-scenes.txt"

      # Add scenes
      cp "$output_dir/$path/add-patterns.txt" "$output_dir/$path/added-scenes.txt"
      if [ -s "$output_dir/$path/add-patterns.txt" ]; then
          cat "$output_dir/$path/add-patterns.txt" \
              >> "$output_dir/$path/tested-scenes.txt" || true
          cat "$output_dir/$path/add-patterns.txt" \
              >> "$output_dir/$path/scenes.txt" || true
      fi

      sed -e "s:^:$path/:" "$output_dir/$path/added-scenes.txt" >> "$output_dir/all-added-scenes.txt"
      sed -e "s:^:$path/:" "$output_dir/$path/tested-scenes.txt" >> "$output_dir/all-tested-scenes.txt"

      # Clean output files
      cat "$output_dir/all-ignored-scenes.txt" | grep "\." | sort | uniq > "$output_dir/all-ignored-scenes.txt.tmp" &&
          mv -f "$output_dir/all-ignored-scenes.txt.tmp" "$output_dir/all-ignored-scenes.txt"
      cat "$output_dir/all-added-scenes.txt"   | grep "\." | sort | uniq > "$output_dir/all-added-scenes.txt.tmp" &&
          mv -f "$output_dir/all-added-scenes.txt.tmp" "$output_dir/all-added-scenes.txt"
      cat "$output_dir/all-tested-scenes.txt"  | grep "\." | sort | uniq > "$output_dir/all-tested-scenes.txt.tmp" &&
          mv -f "$output_dir/all-tested-scenes.txt.tmp" "$output_dir/all-tested-scenes.txt"
}

test-all-scenes() {
    local tested_scenes="$1"
    local $output_dir = $2
    local tested_scenes_count="$(cat "$tested_scenes" | wc -l)"
    current_scene_count=0
    while read scene; do
        current_scene_count=$(( current_scene_count + 1 ))
        local iterations=$(cat "$output_dir/$scene/iterations.txt")
        local options="-g batch -s dag -n $iterations" # -z test

        # Try to guess if a python scene needs SofaPython or SofaPython3
        export PYTHONPATH=""
        if [[ "$scene" == *".py" ]] || [[ "$scene" == *".pyscn" ]]; then
            pythonPlugin="SofaPython3"
            if [[ "$scene" == *"/SofaPython/"* ]]        ||
                grep -q 'createChild' "$src_dir/$scene"  ||
                grep -q 'createObject' "$src_dir/$scene" ||
                grep -q 'print "' "$src_dir/$scene"; then
                    pythonPlugin="SofaPython"
            fi
            options="$options -l $pythonPlugin"

            if [[ "$pythonPlugin" == 'SofaPython3' ]]; then
                if [ -e "$VM_PYTHON3_PYTHONPATH" ]; then
                    export PYTHONPATH="$(cd $VM_PYTHON3_PYTHONPATH && pwd):$PYTHONPATH"
                fi
                if [ -e "$build_dir/python3/site-packages" ]; then
                    export PYTHONPATH="$build_dir/python3/site-packages:$PYTHONPATH"
                fi
                if vm-is-windows && [ -e "$VM_PYTHON3_EXECUTABLE" ]; then
                    pythonroot="$(dirname $VM_PYTHON3_EXECUTABLE)"
                    pythonroot="$(cd "$pythonroot" && pwd)"
                    export PATH="$pythonroot:$pythonroot/DLLs:$pythonroot/Lib:$PATH_RESET"
                fi
            elif [[ "$pythonPlugin" == 'SofaPython' ]]; then
                if [ -e "$VM_PYTHON_PYTHONPATH" ]; then
                    export PYTHONPATH="$(cd $VM_PYTHON_PYTHONPATH && pwd):$PYTHONPATH"
                fi
                if vm-is-windows && [ -e "$VM_PYTHON_EXECUTABLE" ]; then
                    pythonroot="$(dirname $VM_PYTHON_EXECUTABLE)"
                    pythonroot="$(cd "$pythonroot" && pwd)"
                    export PATH="$pythonroot:$pythonroot/DLLs:$pythonroot/Lib:$PATH_RESET"
                fi
            fi
        fi

        local runSofa_cmd="$runSofa $options $src_dir/$scene >> $output_dir/$scene/output.txt 2>&1"
        local timeout=$(cat "$output_dir/$scene/timeout.txt")
        echo "$runSofa_cmd" > "$output_dir/$scene/command.txt"

        echo "- $scene (scene $current_scene_count/$tested_scenes_count)"

        ( echo "" &&
          echo "------------------------------------------" &&
          echo "" &&
          echo "Running scene-test $scene" &&
          echo 'Calling: "'$SCRIPT_DIR'/timeout.sh" "'$output_dir'/'$scene'/runSofa" "'$runSofa_cmd'" '$timeout &&
          echo ""
        ) > "$output_dir/$scene/output.txt"

        begin_millisec="$(time-millisec)"
        "$SCRIPT_DIR/timeout.sh" "$output_dir/$scene/runSofa" "$runSofa_cmd" $timeout
        end_millisec="$(time-millisec)"

        elapsed_millisec="$(( end_millisec - begin_millisec ))"
        elapsed_sec="$(( elapsed_millisec / 1000 )).$(printf "%03d" $elapsed_millisec)"

        if [[ -e "$output_dir/$scene/runSofa.timeout" ]]; then
            echo "Timeout after $timeout seconds ($elapsed_sec)! $scene"
            echo timeout > "$output_dir/$scene/status.txt"
            echo -e "\n\nINFO: Abort caused by timeout.\n" >> "$output_dir/$scene/output.txt"
            rm -f "$output_dir/$scene/runSofa.timeout"
            cat "$output_dir/$scene/timeout.txt" > "$output_dir/$scene/duration.txt"
        else
            cat "$output_dir/$scene/runSofa.exit_code" > "$output_dir/$scene/status.txt"
            elapsed_sec_real="$(grep "iterations done in" "$output_dir/$scene/output.txt" | head -n 1 | sed 's#.*done in \([0-9\.]*\) s.*#\1#')"
            if [ -n "$elapsed_sec_real" ]; then
                echo "$elapsed_sec_real" > "$output_dir/$scene/duration.txt"
            else
                echo "$elapsed_sec" > "$output_dir/$scene/duration.txt"
            fi
        fi
        rm -f "$output_dir/$scene/runSofa.exit_code"
    done < "$tested_scenes"
}

ignore-scenes-python-without-createscene() {
    $output_dir = $1
    echo "Searching for unwanted python scripts..."
    base_dir="$(pwd)"
    (
        cd "$src_dir"
        grep '.py$' "$base_dir/$output_dir/all-tested-scenes.txt" | while read scene; do
            if ! grep -q "def createScene" "$scene"; then
                # Remove the scene from all-tested-scenes
                grep -v "$scene" "$base_dir/$output_dir/all-tested-scenes.txt" > "$base_dir/$output_dir/all-tested-scenes.tmp"
                mv "$base_dir/$output_dir/all-tested-scenes.tmp" "$base_dir/$output_dir/all-tested-scenes.txt"
                rm -f "$base_dir/$output_dir/all-tested-scenes.tmp"
                # Add the scene in all-ignored-scenes
                if ! grep -q "$scene" "$base_dir/$output_dir/all-ignored-scenes.txt"; then
                    echo "  ignore $scene: createScene function not found."
                    echo "$scene" >> "$base_dir/$output_dir/all-ignored-scenes.txt"
                fi
            fi
        done
    )
    echo "Searching for unwanted python scripts: done."
}

extract-errors() {
    $output_dir = $1
    echo "Extracting errors..."
    while read scene; do
        if [[ -e "$output_dir/$scene/output.txt" ]]; then
            sed -ne "/^\[ERROR\] [^]]*/s:\([^]]*\):$scene\: \1:p \
                " "$output_dir/$scene/output.txt"
        fi
    done < "$output_dir/all-tested-scenes.txt" > "$output_dir/reports/errors.tmp"
    sort "$output_dir/reports/errors.tmp" | uniq > "$output_dir/reports/errors.txt"
    rm -f "$output_dir/reports/errors.tmp"
    echo "Done."
}

extract-crashes() {
    $output_dir = $1

    echo "Extracting crashes..."
    rm -rf "$output_dir/archive"
    mkdir "$output_dir/archive"
    while read scene; do
        if [[ -e "$output_dir/$scene/status.txt" ]]; then
            local status="$(cat "$output_dir/$scene/status.txt")"
            if [[ "$status" != 0 ]]; then
                echo "$scene: error: $status"
                scene_path="$(dirname "$scene")"
                if [ ! -d "$output_dir/archive/$scene_path" ]; then
                    mkdir -p "$output_dir/archive/$scene_path"
                fi
                cp -Rf "$output_dir/$scene" "$output_dir/archive/$scene_path" # to be archived for log access
            fi
        fi
    done < "$output_dir/all-tested-scenes.txt" > "$output_dir/reports/crashes.txt"
    echo "Done."
}

extract-successes() {
    $output_dir = $1
    echo "Extracting successes..."
    while read scene; do
        if [[ -e "$output_dir/$scene/status.txt" ]]; then
            local status="$(cat "$output_dir/$scene/status.txt")"
            if [[ "$status" == 0 ]]; then
                grep --silent "\[ERROR\]" "$output_dir/$scene/output.txt" || echo "$scene"
            fi
        fi
    done < "$output_dir/all-tested-scenes.txt" > "$output_dir/reports/successes.tmp"
    sort "$output_dir/reports/successes.tmp" | uniq > "$output_dir/reports/successes.txt"
    rm -f "$output_dir/reports/successes.tmp"
    echo "Done."
}

count-successes() {
    $output_dir = $1
    wc -l < "$output_dir/reports/successes.txt" | tr -d ' 	'
}

count-errors() {
    wc -l < "$output_dir/reports/errors.txt" | tr -d ' 	'
}

count-crashes() {
    $output_dir = $1
    wc -l < "$output_dir/reports/crashes.txt" | tr -d ' 	'
}

print-summary() {
    $output_dir = $1
    echo "Scene testing summary:"
    echo "- $(count-tested-scenes) scene(s) tested"
    echo "- $(count-successes) success(es)"
    echo "- $(count-warnings) warning(s)"

    local errors='$(count-errors)'
    echo "- $(count-errors) error(s)"
    if [[ "$errors" != 0 ]]; then
        sort -u "$output_dir/reports/errors.txt" | while read error; do
			echo "  - $error"
        done
    fi

    local crashes='$(count-crashes)'
    echo "- $(count-crashes) crash(es)"
    if [[ "$crashes" != 0 ]]; then
        while read scene; do
            if [[ -e "$output_dir/$scene/status.txt" ]]; then
                local status="$(cat "$output_dir/$scene/status.txt")"
                    case "$status" in
                    "timeout")
                        echo "  - Timeout: $scene"
                        ;;
                    [0-9]*)
                        if [[ "$status" -gt 128 && ( $(uname) = Darwin || $(uname) = Linux ) ]]; then
                            echo "  - Exit with status $status ($(kill -l $status)): $scene"
                        elif [[ "$status" != 0 ]]; then
                            echo "  - Exit with status $status: $scene"
                        fi
                        ;;
                    *)
                        echo "Error: unexpected value in $output_dir/$scene/status.txt: $status"
                        ;;
                esac
            fi
        done < "$output_dir/all-tested-scenes.txt"
    fi
}