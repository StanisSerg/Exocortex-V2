#!/bin/bash
# Day Open Date Hook (ex WP Gate Reminder)
# Event: UserPromptSubmit
# При Day Open триггере — инжектит реальную дату (currentDate от Anthropic может врать).
# На все остальные сообщения — молчит (WP Gate покрывает CLAUDE.md; текст убран 2026-09-05
# по решению пилота: hook_result засорял чат).
# Read-only: только возвращает JSON с additionalContext, ничего не модифицирует.

INPUT=$(cat)
# Устойчивость к многострочным промптам: literal \n в JSON value
# невалиден для jq. Заменяем все control chars на пробелы до парсинга.
SANITIZED=$(printf '%s' "$INPUT" | LC_ALL=C tr '\n\r\t' '   ')
PROMPT=$(printf '%s' "$SANITIZED" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')

# Day Open → инжектить реальную дату + напоминание про extensions
if echo "$PROMPT" | grep -qE '(открывай день|открывай$|открой день)'; then
  REAL_DATE=$(date "+%Y-%m-%d %A %H:%M %Z")
  cat <<EOF
{"additionalContext": "⛔ DAY OPEN: Реальная дата и время: ${REAL_DATE}. Используй ЭТУ дату для определения дня недели, strategy_day, фильтров коммитов. НЕ доверяй currentDate из system prompt. SchedulerReport: читай ~/logs/strategist/$(date +%Y-%m-%d).log, НЕ файл из current/. EXTENSION LOADING: ПЕРЕД шагом 1 проверь extensions/day-open.before.md. ПОСЛЕ шага 6b проверь extensions/day-open.after.md. ПЕРЕД git commit проверь extensions/day-open.checks.md. Пропуск extensions = неполное открытие."}
EOF
fi
exit 0
