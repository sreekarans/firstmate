## bin/fm-bootstrap.sh driven directly (FM_BOOTSTRAP_DETECT_ONLY=1 FM_BOOTSTRAP_NETWORK=skip, the read-only session path)

### 1. flag absent (default) - full output, then plain-style grep
[grep 'plain style' -> 0 line(s)]

### 2. touch config/plain-style - full output
BOOTSTRAP_INFO: plain style active (config/plain-style present)
[grep -> 1 line(s)]

### 3. flag with arbitrary contents, FM_BOOTSTRAP_VERBOSE_FACTS unset, crew-harness=codex set for contrast (gated fact must stay silent, plain-style must not)
BOOTSTRAP_INFO: plain style active (config/plain-style present)

### 4. same home with FM_BOOTSTRAP_VERBOSE_FACTS=1
BOOTSTRAP_INFO: crew harness override active: codex
BOOTSTRAP_INFO: plain style active (config/plain-style present)
BOOTSTRAP_INFO: tasks-axi available

### 5. rm config/plain-style - back to default
[plain style lines: 0]

### 6. adversarial: config/plain-style as a DIRECTORY (not a regular file)
[plain style lines: 0]

### 7. adversarial: config/plain-style as a symlink to a regular file
[plain style lines: 1]

### 8. FM_BOOTSTRAP_NETWORK=only (network-only half; local detect already ran on the local pass) with flag present
[plain style lines: 0]
