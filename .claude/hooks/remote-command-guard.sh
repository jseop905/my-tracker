#!/bin/bash
# remote-command-guard.sh - PreToolUse 훅 (Bash)
# 원격 세션에서 위험한 Bash 명령을 차단
#
# 트리거: PreToolUse, 매처: Bash
# 종료 코드: 0 = 허용, 2 = 차단
#
# 원격 세션 감지: SSH_CONNECTION, SSH_TTY, REMOTE_SESSION 환경변수
# 로컬 세션에서는 검사를 건너뜀
#
# 차단 범주:
#   1. 파괴적 삭제 (rm -rf /, rm -rf ~, rm -rf *)
#   2. 환경변수/시크릿 유출 (env, printenv, echo $SECRET 등)
#   3. 민감 시스템 경로 접근 (/etc/passwd, /etc/shadow 등)
#   4. 외부 네트워크 통신 (curl, wget, nc 등 - localhost 제외)
#   5. 권한 변경 (chmod 777, sudo 등)
#   6. 프로세스 종료/시스템 제어 (kill -9, shutdown 등)
#   7. 명령 주입 (eval, exec, sh로 파이프 등)

# 로컬 세션이면 검사 건너뜀
if [[ -z "${SSH_CONNECTION:-}" && -z "${SSH_TTY:-}" && -z "${REMOTE_SESSION:-}" ]]; then
    exit 0
fi

# Python 경로 자동 감지 (Windows 대응)
PYTHON_CMD=""
for cmd in python3 python py; do
    if "$cmd" -c "import sys" &>/dev/null 2>&1; then
        PYTHON_CMD="$cmd"
        break
    fi
done

if [[ -z "$PYTHON_CMD" ]]; then
    exit 0
fi

INPUT=$(cat)

_TMPDIR="${TMPDIR:-${TEMP:-${TMP:-/tmp}}}"
_SCRIPT_FILE=$(mktemp "${_TMPDIR}/hook-XXXXXX.py")
trap 'rm -f "$_SCRIPT_FILE"' EXIT

cat > "$_SCRIPT_FILE" << 'GUARD_SCRIPT'
import sys
import json
import re

input_json = sys.stdin.read()
if not input_json:
    sys.exit(0)

try:
    data = json.loads(input_json)
except Exception:
    sys.exit(0)

command = data.get("tool_input", {}).get("command", "")
if not command:
    sys.exit(0)

# 명령 정규화
cmd = re.sub(r'\s+', ' ', command.strip())
cmd_lower = cmd.lower()

blocked_reason = None

# === 1. 파괴적 삭제 ===
destructive_patterns = [
    r'\brm\s+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\s',
    r'\brm\s+-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*\s',
    r'\brm\b.*\s+/$',
    r'\brm\b.*\s+/\s',
    r'\brm\b.*\s+~/?(\s|$)',
    r'\brm\b.*\s+\*(\s|$)',
    r'\bmkfs\b',
    r'\bdd\s+.*of=/dev/',
]
for pat in destructive_patterns:
    if re.search(pat, cmd_lower):
        blocked_reason = "파괴적 삭제 명령 감지"
        break

# === 2. 환경변수/시크릿 유출 ===
if not blocked_reason:
    secret_patterns = [
        r'\b(env|printenv|set)\s*$',
        r'\b(env|printenv|set)\s*\|',
        r'\becho\s+.*\$[A-Z_]*KEY\b',
        r'\becho\s+.*\$[A-Z_]*SECRET\b',
        r'\becho\s+.*\$[A-Z_]*TOKEN\b',
        r'\becho\s+.*\$[A-Z_]*PASSWORD\b',
        r'\becho\s+.*\$[A-Z_]*API\b',
        r'\becho\s+.*\$[A-Z_]*CREDENTIAL\b',
        r'\bcat\s+.*\.env\b',
        r'\bcat\s+.*\.netrc\b',
        r'\bcat\s+.*credentials\b',
        r'\bcat\s+.*/\.ssh/',
        r'\bexport\s+-p\s*$',
        r'\bexport\s+-p\s*\|',
    ]
    for pat in secret_patterns:
        if re.search(pat, cmd, re.IGNORECASE):
            blocked_reason = "시크릿/환경변수 유출 시도 감지"
            break

# === 3. 민감 시스템 경로 접근 ===
if not blocked_reason:
    path_patterns = [
        r'/etc/passwd',
        r'/etc/shadow',
        r'/etc/sudoers',
        r'\.\./(\.\./)*(etc|proc|sys|dev)/',
        r'/proc/self/',
        r'/proc/\d+/',
    ]
    for pat in path_patterns:
        if re.search(pat, cmd_lower):
            blocked_reason = "민감 시스템 경로 접근 감지"
            break

# === 4. 외부 네트워크 통신 ===
if not blocked_reason:
    network_patterns = [
        r'\bcurl\s',
        r'\bwget\s',
        r'\bnc\s',
        r'\bncat\s',
        r'\bnetcat\s',
        r'\btelnet\s',
        r'\bssh\s+(?!.*git)',
        r'\bscp\s',
        r'\brsync\s.*:',
        r'\bftp\s',
        r'\bsftp\s',
        r'\bsocat\s',
        r'\bnpm\s+publish\b',
    ]
    # localhost/127.0.0.1 대상은 허용 (로컬 개발용)
    is_local = bool(re.search(
        r'\b(curl|wget)\s+.*\b(localhost|127\.0\.0\.1|0\.0\.0\.0)\b', cmd_lower
    ))
    if not is_local:
        for pat in network_patterns:
            if re.search(pat, cmd_lower):
                blocked_reason = "외부 네트워크 통신 시도 감지"
                break

# === 5. 권한 변경 ===
if not blocked_reason:
    permission_patterns = [
        r'\bchmod\s+777\b',
        r'\bchmod\s+666\b',
        r'\bchown\s',
        r'\bmount\s',
        r'\bumount\s',
        r'\bsudo\s',
        r'\bsu\s+-?\s',
    ]
    for pat in permission_patterns:
        if re.search(pat, cmd_lower):
            blocked_reason = "권한 변경 명령 감지"
            break

# === 6. 프로세스 종료/시스템 제어 ===
if not blocked_reason:
    process_patterns = [
        r'\bkill\s+-9\b',
        r'\bkill\s+-KILL\b',
        r'\bkillall\s',
        r'\bpkill\s',
        r'\bshutdown\b',
        r'\breboot\b',
        r'\bhalt\b',
    ]
    for pat in process_patterns:
        if re.search(pat, cmd_lower):
            blocked_reason = "프로세스 종료/시스템 제어 명령 감지"
            break

# === 7. 명령 주입 ===
if not blocked_reason:
    injection_patterns = [
        r'\beval\s',
        r'(?<!\bdocker\s)\bexec\s',
        r'\bsource\s+/dev/',
        r'\bbash\s+-c\s.*\$\(',
        r'\bsh\s+-c\s.*\$\(',
        r'\|\s*sh\b',
        r'\|\s*bash\b',
        r'\bbase64\s+-d\s*\|\s*(sh|bash)',
    ]
    for pat in injection_patterns:
        if re.search(pat, cmd_lower):
            blocked_reason = "명령 주입 패턴 감지"
            break

if blocked_reason:
    safe_cmd = cmd[:200]
    print(f"BLOCKED: {blocked_reason}", file=sys.stderr)
    print(f"Command: {safe_cmd}", file=sys.stderr)
    sys.exit(2)

sys.exit(0)
GUARD_SCRIPT

echo "$INPUT" | $PYTHON_CMD "$_SCRIPT_FILE"
