## Guarded fast-forward update: flag set vs. hand-edited AGENTS.md
Both clones start at base 9074f9d20d3dd6b632051623f71797084a7aab36; origin main then advances to target a32a9eb5537a3ed1d66af663fec2ec6551aafd9e.

### flagged clone (config/plain-style present, AGENTS.md untouched)
HEAD before: 9074f9d20d3dd6b632051623f71797084a7aab36
git status --porcelain: [] (0 lines)
git check-ignore -v config/plain-style: .gitignore:13:config/	config/plain-style

$ FM_HOME=$PWD bin/fm-update.sh
firstmate: updated 9074f9d..a32a9eb (instructions changed: AGENTS.md, bin)
reread-firstmate: yes
restart-secondmates: none
nudge-secondmates: none
[exit=0]
HEAD after: a32a9eb5537a3ed1d66af663fec2ec6551aafd9e
config/plain-style still present after update: yes

$ FM_HOME=$PWD FM_BOOTSTRAP_DETECT_ONLY=1 FM_BOOTSTRAP_NETWORK=skip bin/fm-bootstrap.sh | grep BOOTSTRAP_INFO   (now running the updated code)
BOOTSTRAP_INFO: plain style active (config/plain-style present)

### edited clone (hand-edited AGENTS.md, the approach the flag replaces)
HEAD before: 9074f9d20d3dd6b632051623f71797084a7aab36
git status --porcelain: [ M AGENTS.md ]

$ FM_HOME=$PWD bin/fm-update.sh
firstmate: skipped: dirty working tree
reread-firstmate: no
restart-secondmates: none
nudge-secondmates: none
[exit=0]
HEAD after: 9074f9d20d3dd6b632051623f71797084a7aab36
hand edit preserved: 1
