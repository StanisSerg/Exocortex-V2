#!/bin/bash
# WP Gate Reminder Hook
# Event: UserPromptSubmit
# (1) При Day Open триггере — инжектит реальную дату (currentDate от Anthropic может врать).
# (2) На все остальные сообщения — стандартный WP Gate reminder.
# Read-only: только возвращает JSON с additionalContext, ничего не модифицирует.

INPUT=$(cat)
# Устойчивость к многострочным промптам: literal \n в JSON value
# невалиден для jq. Заменяем все control chars на пробелы до парсинга.
SANITIZED=$(printf '%s' "$INPUT" | LC_ALL=C tr '\n\r\t' '   ')
PROMPT=$(printf '%s' "$SANITIZED" | jq -r '.prompt // empty' | tr '[:upper:]' '[:lower:]')

# Day Open → инжектить реальную дату + WP Gate
if echo "$PROMPT" | grep -qE '(открывай день|открывай$|открой день)'; then
  REAL_DATE=$(date "+%Y-%m-%d %A %H:%M %Z")
  cat <<EOF
{"additionalContext": "⛔ DAY OPEN: Реальная дата и время: ${REAL_DATE}. Используй ЭТУ дату для определения дня недели, strategy_day, фильтров коммитов. НЕ доверяй currentDate из system prompt. SchedulerReport: читай ~/logs/strategist/$(date +%Y-%m-%d).log, НЕ файл из current/. EXTENSION LOADING: ПЕРЕД шагом 1 проверь extensions/day-open.before.md. ПОСЛЕ шага 6b проверь extensions/day-open.after.md. ПЕРЕД git commit проверь extensions/day-open.checks.md. Пропуск extensions = неполное открытие."}
EOF
# Дефолт: молчим (пустой stdout). Постоянный WP Gate reminder на каждом
# сообщении всплывал в чате Kimi CLI блоком hook_result (2026-08-28);
# напоминание WP Gate модель и так получает из AGENTS.md («WP Gate — CRITICAL»).
fi
exit 0
