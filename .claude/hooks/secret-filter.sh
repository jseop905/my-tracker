#!/bin/bash
# secret-filter.sh - PostToolUse 훅 (모든 도구)
# 도구 실행 결과에서 시크릿을 감지하여 마스킹
#
# 트리거: PostToolUse (Bash)
# 종료 코드: 0 = 항상 허용 (출력만 수정)
#
# 동작 방식:
#   - stdin으로 도구 실행 결과 JSON 수신
#   - tool_result에서 시크릿 패턴 감지
#   - 3계층 탐지: 원본 → Base64 디코딩 → URL 디코딩
#   - 감지 시 마스킹된 결과를 stdout으로 출력
#   - 마스킹 발생 시 security.log에 기록

# Python 경로 자동 감지 (Windows 대응)
PYTHON_CMD=""
for cmd in python3 python py; do
    if "$cmd" -c "import sys" &>/dev/null 2>&1; then
        PYTHON_CMD="$cmd"
        break
    fi
done

if [[ -z "$PYTHON_CMD" ]]; then
    # Python 없으면 필터링 없이 통과
    exit 0
fi

# stdin으로 JSON 수신
INPUT=$(cat)

export _SECURITY_LOG="${CLAUDE_PROJECT_DIR:-.}/.claude/security.log"

_TMPDIR="${TMPDIR:-${TEMP:-${TMP:-/tmp}}}"
_SCRIPT_FILE=$(mktemp "${_TMPDIR}/hook-XXXXXX.py")
trap 'rm -f "$_SCRIPT_FILE"' EXIT

cat > "$_SCRIPT_FILE" << 'FILTER_SCRIPT'
import sys
import json
import re
import os
import base64
import urllib.parse
from datetime import datetime

input_json = sys.stdin.read()
security_log = os.environ.get("_SECURITY_LOG", "")

if not input_json:
    sys.exit(0)

try:
    data = json.loads(input_json)
except (json.JSONDecodeError, ValueError):
    sys.exit(0)

# tool_result에서 텍스트 추출
tool_result = data.get("tool_result", "")
if isinstance(tool_result, dict):
    tool_result = json.dumps(tool_result, ensure_ascii=False)
elif not isinstance(tool_result, str):
    tool_result = str(tool_result)

if not tool_result:
    sys.exit(0)

# 마스킹 패턴 정의 (패턴, 설명)
SECRET_PATTERNS = [
    # API 키 패턴
    (r'\bsk-[a-zA-Z0-9_-]{20,}\b', "OpenAI API 키"),
    (r'\bsk-proj-[a-zA-Z0-9_-]{20,}\b', "OpenAI 프로젝트 키"),
    (r'\bAKIA[A-Z0-9]{16,}\b', "AWS 액세스 키"),
    (r'\bxoxb-[a-zA-Z0-9-]{20,}\b', "Slack 봇 토큰"),
    (r'\bxoxp-[a-zA-Z0-9-]{20,}\b', "Slack 사용자 토큰"),
    (r'\bghp_[a-zA-Z0-9]{36,}\b', "GitHub PAT"),
    (r'\bghs_[a-zA-Z0-9]{36,}\b', "GitHub 앱 토큰"),
    (r'\bgho_[a-zA-Z0-9]{36,}\b', "GitHub OAuth 토큰"),
    (r'\bghu_[a-zA-Z0-9]{36,}\b', "GitHub 사용자 토큰"),
    (r'\bgithub_pat_[a-zA-Z0-9_]{20,}\b', "GitHub 세분화 PAT"),
    (r'\bglpat-[a-zA-Z0-9_-]{20,}\b', "GitLab PAT"),
    (r'\bnpm_[a-zA-Z0-9]{36,}\b', "NPM 토큰"),
    (r'\bsk_(live|test)_[a-zA-Z0-9]{20,}\b', "Stripe 키"),
    (r'\bAIzaSy[a-zA-Z0-9_-]{33}\b', "Google API 키"),
    (r'\bAccountKey=[a-zA-Z0-9+/]{40,}\b', "Azure 스토리지 키"),
    (r'\bSG\.[a-zA-Z0-9_-]{22}\b', "SendGrid API 키"),

    # Bearer/Auth 토큰
    (r'(?i)\bBearer\s+[a-zA-Z0-9_.-]{20,}\b', "Bearer 토큰"),
    (r'(?i)\btoken=[a-zA-Z0-9_.-]{20,}\b', "토큰 파라미터"),
    (r'(?i)\bauth=[a-zA-Z0-9_.-]{20,}\b', "인증 파라미터"),
    (r'(?i)\bapi[_-]?key=[a-zA-Z0-9_.-]{20,}\b', "API 키 파라미터"),

    # 비밀번호/시크릿 패턴
    (r'(?i)\bpassword=[^\s&]{8,}\b', "비밀번호 파라미터"),
    (r'(?i)\bpasswd=[^\s&]{8,}\b', "비밀번호 파라미터"),
    (r'(?i)\bsecret=[^\s&]{20,}\b', "시크릿 파라미터"),

    # 환경변수 값 (KEY=VALUE)
    (r'(?i)\bAWS_SECRET_ACCESS_KEY=[^\s]{20,}\b', "AWS 시크릿 키"),
    (r'(?i)\bOPENAI_API_KEY=[^\s]{20,}\b', "OpenAI 키 값"),
    (r'(?i)\bANTHROPIC_API_KEY=[^\s]{20,}\b', "Anthropic 키 값"),
    (r'(?i)\bGITHUB_TOKEN=[^\s]{20,}\b', "GitHub 토큰 값"),
    (r'(?i)\bDATABASE_URL=[^\s]{20,}\b', "데이터베이스 URL 값"),

    # 개인 키 블록
    (r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----', "개인 키"),

    # 긴 Base64 시크릿 (key/secret/token 컨텍스트)
    (r'(?i)(?:key|secret|token|password|credential|auth)[\s=:]+["\']?[a-zA-Z0-9+/]{40,}={0,2}["\']?', "Base64 인코딩 시크릿 추정"),
]


def decode_layers(text):
    """Base64, URL 인코딩을 디코딩하여 숨겨진 시크릿 탐지"""
    decoded_variants = []
    # base64 디코딩 시도
    b64_pattern = re.compile(r'[A-Za-z0-9+/]{20,}={0,2}')
    for m in b64_pattern.finditer(text):
        try:
            decoded = base64.b64decode(m.group(0), validate=True).decode("utf-8", errors="ignore")
            if decoded and len(decoded) >= 10:
                decoded_variants.append(decoded)
        except Exception:
            pass
    # URL 디코딩 시도
    try:
        url_decoded = urllib.parse.unquote(text)
        if url_decoded != text:
            decoded_variants.append(url_decoded)
    except Exception:
        pass
    return decoded_variants


def mask_match(original):
    """매칭된 문자열 마스킹"""
    if len(original) > 16:
        return original[:8] + "***MASKED***" + original[-4:]
    return original[:4] + "***MASKED***"


masked_output = tool_result
masked_count = 0
masked_types = []

# 1계층: 원본 텍스트에서 직접 매칭
for pattern, desc in SECRET_PATTERNS:
    matches = list(re.finditer(pattern, masked_output))
    if matches:
        for match in reversed(matches):
            original = match.group(0)
            masked_output = masked_output[:match.start()] + mask_match(original) + masked_output[match.end():]
            masked_count += 1
        if desc not in masked_types:
            masked_types.append(desc)

# 2·3계층: 인코딩 우회 탐지
decoded_variants = decode_layers(tool_result)
for decoded_text in decoded_variants:
    for pattern, desc in SECRET_PATTERNS:
        if re.search(pattern, decoded_text):
            # Base64로 인코딩된 시크릿 마스킹
            b64_pattern = re.compile(r'[A-Za-z0-9+/]{20,}={0,2}')
            for m in b64_pattern.finditer(masked_output):
                try:
                    d = base64.b64decode(m.group(0), validate=True).decode("utf-8", errors="ignore")
                    if re.search(pattern, d):
                        chunk = m.group(0)
                        masked_output = masked_output[:m.start()] + mask_match(chunk) + masked_output[m.end():]
                        masked_count += 1
                        if desc not in masked_types:
                            masked_types.append(desc)
                        break
                except Exception:
                    pass
            # URL로 인코딩된 시크릿 마스킹
            try:
                url_decoded = urllib.parse.unquote(masked_output)
                if url_decoded != masked_output and re.search(pattern, url_decoded):
                    pct_pattern = re.compile(r'(?:%[0-9A-Fa-f]{2}[A-Za-z0-9_.~-]*){5,}')
                    for pm in reversed(list(pct_pattern.finditer(masked_output))):
                        decoded_chunk = urllib.parse.unquote(pm.group(0))
                        if re.search(pattern, decoded_chunk):
                            masked_output = masked_output[:pm.start()] + mask_match(pm.group(0)) + masked_output[pm.end():]
                            masked_count += 1
                            if desc not in masked_types:
                                masked_types.append(desc)
            except Exception:
                pass

if masked_count > 0:
    # 마스킹된 결과를 stdout으로 출력
    print(masked_output)

    # 보안 로그 기록 (시크릿 값 자체는 기록하지 않음)
    if security_log:
        try:
            log_dir = os.path.dirname(security_log)
            if log_dir:
                os.makedirs(log_dir, exist_ok=True)
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            tool_name = data.get("tool_name", "unknown")
            log_entry = (
                f"{timestamp} | SECRET_MASKED | tool={tool_name} | "
                f"count={masked_count} | types={','.join(masked_types)}\n"
            )
            with open(security_log, "a") as f:
                f.write(log_entry)
        except (IOError, OSError):
            pass

# 항상 허용 (종료 코드 0)
sys.exit(0)
FILTER_SCRIPT

echo "$INPUT" | $PYTHON_CMD "$_SCRIPT_FILE"
