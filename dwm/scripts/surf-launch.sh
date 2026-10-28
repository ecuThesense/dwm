# #!/bin/sh
# Pick a bookmark ("name | URL"), paste a link, or type a query to web-search.
bm="$HOME/.surf/bookmarks.html"

search_url() {
    q=$(printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n' | sed 's/../%&/g')
    printf 'https://www.startpage.com/do/dsearch?query=%s' "$q"
}

# url<TAB>title, with HTML entities decoded up front
pairs=""
[ -s "$bm" ] && pairs=$(sed -n 's/.*<A HREF="\([^"]*\)"[^>]*>\(.*\)<\/A>.*/\1\t\2/p' "$bm" |
                        sed 's/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&amp;/\&/g')

sel=$(printf '%s\n' "$pairs" | awk -F'\t' 'NF>=2{print $2 " | " $1}' | sort -f |
      dmenu -fn monospace:size=14 -i -l 10 -p 'Bookmark / URL / Search:')
[ -z "$sel" ] && exit 0

# did we pick a "name | URL" line? then take its URL
url=$(printf '%s\n' "$pairs" |
      T="$sel" awk -F'\t' 'NF>=2 && ($2 " | " $1)==ENVIRON["T"]{print $1; exit}')

if [ -z "$url" ]; then
    case "$sel" in
        http://*|https://*|file://*|about:*)
            url=$sel ;;                       # full link
        *[[:space:]]*)
            url=$(search_url "$sel") ;;       # several words: search
        *.*)
            url="https://$sel" ;;             # bare domain
        *)
            url=$(search_url "$sel") ;;       # single word: search
    esac
fi

exec surf -z 1.5 "$url"
