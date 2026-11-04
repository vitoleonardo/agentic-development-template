# shellcheck shell=sh
# The acceptance-criterion check that spec-lint and plan-lint share, as awk source to concatenate
# into their programs. It defines problem-free helpers only; the program supplies problem(line, message).
#   check_criterion(line, id, text): text must read "Given <state>, when <action>, then <one result>"
#   and hold no word of the untestable list; each violation is reported through problem().
# nvague and vague[] are set by criterion_check_init(), which the program calls in its BEGIN block.

# shellcheck disable=SC2034
CRITERION_CHECK='
  # Lowercase words separated by single spaces, padded so " word " always matches whole words.
  function words(text,    t) {
    t = tolower(text)
    gsub(/[^a-z0-9-]+/, " ", t)
    return " " t " "
  }

  function count(haystack, needle,    n, i) {
    n = 0
    while ((i = index(haystack, needle)) > 0) { n++; haystack = substr(haystack, i + length(needle)) }
    return n
  }

  function criterion_check_init() {
    nvague = split("fast|quickly|slow|user-friendly|intuitive|easy|easily|properly|correctly|appropriate|appropriately|reasonable|nice|good|better|best|etc|and so on|as needed|should work|works well|robust|seamless|seamlessly|efficient|efficiently|optimal|tbd|todo|handle|handles|support|supports", vague, "|")
  }

  function check_criterion(line, id, text,    t, g, w, th, i) {
    t = words(text)
    g = index(t, " given "); w = index(t, " when "); th = index(t, " then ")
    if (!(g && w && th && g < w && w < th))
      problem(line, id ": write it as \"Given <state>, when <action>, then <observable result>\".")
    else if (count(t, " then ") > 1)
      problem(line, id ": has more than one \"then\"; split it so each criterion is one yes/no check.")
    for (i = 1; i <= nvague; i++)
      if (index(t, " " vague[i] " "))
        problem(line, id ": \"" vague[i] "\" cannot be tested; state a concrete, observable result (numbers, exact text, states).")
  }
'
