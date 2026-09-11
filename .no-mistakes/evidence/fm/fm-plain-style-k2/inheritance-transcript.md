## Secondmate inheritance of config/plain-style via bin/fm-config-push.sh (primary-authoritative)

### 1. primary has no flag, secondmate has none: no-op
config-push: /tmp/fm-plain-style-inherit.lgNhzg/home -> live secondmate homes
secondmate sm (/private/tmp/fm-plain-style-inherit.lgNhzg/sm):
  plain-style: unchanged
secondmate config/plain-style: absent

### 2. touch <primary>/config/plain-style, then push
config-push: /tmp/fm-plain-style-inherit.lgNhzg/home -> live secondmate homes
secondmate sm (/private/tmp/fm-plain-style-inherit.lgNhzg/sm):
  plain-style: pushed
CONFIG_REREAD: secondmate sm: send failed: error: no-mistakes gate agent must not drive the fleet (NO_MISTAKES_GATE set)
secondmate config/plain-style: PRESENT

### 3. push again with nothing changed (idempotent)
config-push: /tmp/fm-plain-style-inherit.lgNhzg/home -> live secondmate homes
secondmate sm (/private/tmp/fm-plain-style-inherit.lgNhzg/sm):
  plain-style: unchanged
secondmate config/plain-style: PRESENT

### 4. rm <primary>/config/plain-style, then push (absence mirror)
config-push: /tmp/fm-plain-style-inherit.lgNhzg/home -> live secondmate homes
secondmate sm (/private/tmp/fm-plain-style-inherit.lgNhzg/sm):
  plain-style: pushed - mirrored primary absence
secondmate config/plain-style: absent

### 5. adversarial: flag created ONLY in the secondmate home, primary still without it, then push (accepted primary-authoritative design)
config-push: /tmp/fm-plain-style-inherit.lgNhzg/home -> live secondmate homes
secondmate sm (/private/tmp/fm-plain-style-inherit.lgNhzg/sm):
  plain-style: pushed - mirrored primary absence
secondmate config/plain-style: absent

### 6. adversarial: primary config/plain-style is a DIRECTORY, secondmate has the flag: must error, not silently copy or delete
config-push: /tmp/fm-plain-style-inherit.lgNhzg/home -> live secondmate homes
secondmate sm (/private/tmp/fm-plain-style-inherit.lgNhzg/sm):
fm-config-inherit: error: primary source is not a regular file plain-style at /tmp/fm-plain-style-inherit.lgNhzg/home/config/plain-style
  plain-style: error - primary source is not a regular file
[exit=1]
secondmate config/plain-style: PRESENT

### 7. adversarial: destination repo does NOT gitignore config/ (guard must skip, never write a tracked file)
config-push: /tmp/fm-plain-style-inherit.lgNhzg/home -> live secondmate homes
secondmate sm (/private/tmp/fm-plain-style-inherit.lgNhzg/sm):
fm-config-inherit: warning: skipped plain-style for /private/tmp/fm-plain-style-inherit.lgNhzg/sm/config: destination does not allow inherited item (not gitignored or guard failed)
  plain-style: skipped - destination does not allow inherited item (not gitignored or guard failed)
secondmate config/plain-style: absent
secondmate git status --porcelain: []
