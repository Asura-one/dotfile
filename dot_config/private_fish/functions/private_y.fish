function y --description 'Launch yazi and cd to the last visited directory on exit'
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set -l cwd (cat "$tmp")
        and test -n "$cwd"
        and test "$cwd" != "$PWD"
        cd "$cwd"
    end
    rm -f "$tmp"
end
