# macOS 10.15 "Catalina" has some major issues.
# The whatis database is non-existent, so apropos tries (and fails) to create it every time,
# which takes about half a second.
#
# So we disable this entirely in that case, unless the user has overridden the system
# `apropos` with their own, which presumably doesn't have the same problem.
if test (uname) = Darwin
    set -l darwin_version (uname -r | string split .)
    # macOS 15 is Darwin 19, this is an issue at least up to 10.15.3.
    # If this is fixed in later versions uncomment the second check.
    if test "$darwin_version[1]" = 19 # -a "$darwin_version[2]" -le 3
        set -l apropos (command -s apropos)
        if test "$apropos" = "/usr/bin/apropos"
            function __fish_complete_man
            end
            # (remember: exit when `source`ing only exits the file, not the shell)
            exit
        end
    end
end

function __fish_complete_man
    # Try to guess what section to search in. If we don't know, we
    # use [^)]*, which should match any section.
    set -l section ""
    set -l token (commandline -ct)
    set -l prev (commandline -poc)
    set -e prev[1]
    while set -q prev[1]
        switch $prev[1]
            case '-**'

            case '*'
                set section (string escape --style=regex $prev[1])
                set section (string replace --all / \\/ $section)
        end
        set -e prev[1]
    end

    set -l exclude_fish_commands
    # Only include fish commands when section is empty or 1
    if test -z "$section" -o "$section" = 1
        set -e exclude_fish_commands
    end

    set section $section"[^)]*"
    # If we don't have a token but a section, list all pages for that section.
    # Don't do it for all sections because that would be overwhelming.
    if test -z "$token" -a "$section" != "[^)]*"
        set token "."
    end

    if test -n "$token"
        # Do the actual search
        apropos $token 2>/dev/null | awk '
                BEGIN { FS="[\t ]- "; OFS="\t"; }
                # BSD/Darwin
                /^[^( \t]+\('$section'\)/ {
                  split($1, pages, ", ");
                  for (i in pages) {
                    page = pages[i];
                    sub(/[ \t]+/, "", page);
                    paren = index(page, "(");
                    name = substr(page, 1, paren - 1);
                    sect = substr(page, paren + 1, length(page) - paren - 1);
                    print name, sect ": " $2;
                  }
                }
                # man-db
                /^[^( \t]+ +\('$section'\)/ {
                  split($1, t, " ");
                  sect = substr(t[2], 2, length(t[2]) - 2);
                  print t[1], sect ": " $2;
                }
                # man-db RHEL 5 with [aliases]
                /^[^( \t]+ +\[.*\] +\('$section'\)/ {
                  split($1, t, " ");
                  sect = substr(t[3], 2, length(t[3]) - 2);
                  print t[1], sect ": " $2;
                }
                # Solaris 11
                # Does not display descriptions
                # Solaris apropos outputs embedded backspace in descriptions
                /^[0-9]+\. [^( \t]*\('$section'\) / {
                  split($1, t, " ")
                  paren = index(t[2], "(");
                  name = substr(t[2], 1, paren - 1);
                  sect = substr(t[2], paren + 1, length(t[2]) - paren - 1);
                  print name, sect
                }
                '

        # Fish commands are not given by apropos
        if not set -ql exclude_fish_commands
            set -l files $__fish_data_dir/man/man1/*.1
            string replace -r '.*/([^/]+)\.1$' '$1\t1: fish command' -- $files
        end
    else
        return 1
    end
    return 0
end

