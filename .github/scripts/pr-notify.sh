#!/bin/bash
# Discord PR notification script
# Sends rich PR notifications with description, comments, labels, etc.

set -e

EVENT_TYPE="${GITHUB_EVENT_NAME}"
ACTION="${PR_ACTION}"
PR_TITLE="${PR_TITLE}"
PR_NUMBER="${PR_NUMBER}"
PR_URL="${PR_URL}"
PR_AUTHOR="${PR_AUTHOR}"
PR_MERGED="${PR_MERGED}"
PR_MERGED_BY="${PR_MERGED_BY}"
REPO="${GITHUB_REPOSITORY}"
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)
HEAD_REF="${PR_HEAD_REF}"
BASE_REF="${PR_BASE_REF}"

ADDITIONS="${PR_ADDITIONS:-0}"
DELETIONS="${PR_DELETIONS:-0}"
CHANGED_FILES="${PR_CHANGED_FILES:-0}"
COMMENTS="${PR_COMMENTS:-0}"
REVIEW_COMMENTS="${PR_REVIEW_COMMENTS:-0}"
IS_DRAFT="${PR_DRAFT:-false}"
LABELS="${PR_LABELS:-}"

REVIEWER="${REVIEWER:-}"
REVIEW_STATE="${REVIEW_STATE:-}"

TOTAL_COMMENTS=$((COMMENTS + REVIEW_COMMENTS))

PR_BODY_TRUNCATED=""
if [ -n "$PR_BODY" ]; then
  PR_BODY_TRUNCATED=$(echo "$PR_BODY" | head -c 200)
  if [ ${#PR_BODY} -gt 200 ]; then
    PR_BODY_TRUNCATED="${PR_BODY_TRUNCATED}..."
  fi
  PR_BODY_TRUNCATED=$(echo "$PR_BODY_TRUNCATED" | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/\r//g')
fi

COLOR=5865426
EMOJI=""
TITLE=""
DESCRIPTION=""

if [ "$EVENT_TYPE" == "pull_request" ]; then
  case "$ACTION" in
    opened|reopened)
      if [ "$IS_DRAFT" == "true" ]; then
        EMOJI="📝"; TITLE="Draft PR Opened"; COLOR=9807270
      else
        EMOJI="📝"; TITLE="New Pull Request"; COLOR=5793266
      fi
      DESCRIPTION="**${PR_AUTHOR}** opened a new PR"
      ;;
    ready_for_review)
      EMOJI="🚀"; TITLE="PR Ready for Review"; COLOR=5793266
      DESCRIPTION="**${PR_AUTHOR}** marked PR as ready for review"
      ;;
    closed)
      if [ "$PR_MERGED" == "true" ]; then
        EMOJI="🎉"; TITLE="Pull Request Merged"; COLOR=10181046
        DESCRIPTION="**${PR_MERGED_BY}** merged the PR"
      else
        EMOJI="❌"; TITLE="Pull Request Closed"; COLOR=15548997
        DESCRIPTION="PR was closed without merging"
      fi
      ;;
    review_requested)
      EMOJI="👀"; TITLE="Review Requested"; COLOR=16776960
      DESCRIPTION="**${PR_AUTHOR}** requested review from **${REVIEWER}**"
      ;;
  esac
elif [ "$EVENT_TYPE" == "pull_request_review" ]; then
  case "$REVIEW_STATE" in
    approved)
      EMOJI="✅"; TITLE="PR Approved"; COLOR=5793266
      DESCRIPTION="**${REVIEWER}** approved the PR"
      ;;
    changes_requested)
      EMOJI="🔄"; TITLE="Changes Requested"; COLOR=15105570
      DESCRIPTION="**${REVIEWER}** requested changes"
      ;;
    commented)
      EMOJI="💬"; TITLE="Review Comment"; COLOR=5865426
      DESCRIPTION="**${REVIEWER}** commented on the PR"
      ;;
  esac
fi

if [ -z "$TITLE" ]; then
  echo "Unknown event type, skipping notification"
  exit 0
fi

FULL_DESCRIPTION="${DESCRIPTION}"
if [ -n "$PR_BODY_TRUNCATED" ]; then
  FULL_DESCRIPTION="${FULL_DESCRIPTION}\n\n> ${PR_BODY_TRUNCATED}"
fi
FULL_DESCRIPTION="${FULL_DESCRIPTION}\n\n**[#${PR_NUMBER} ${PR_TITLE}](${PR_URL})**"

FIELDS='[
  {"name": "Repo", "value": "`'"${REPO_NAME}"'`", "inline": true},
  {"name": "Branch", "value": "`'"${HEAD_REF}"'` → `'"${BASE_REF}"'`", "inline": true},
  {"name": "Changes", "value": "`+'"${ADDITIONS}"' -'"${DELETIONS}"'` ('"${CHANGED_FILES}"' files)", "inline": true}'

if [ "$TOTAL_COMMENTS" -gt 0 ]; then
  FIELDS="${FIELDS}, {\"name\": \"Comments\", \"value\": \"${TOTAL_COMMENTS} 💬\", \"inline\": true}"
fi

if [ -n "$LABELS" ]; then
  FIELDS="${FIELDS}, {\"name\": \"Labels\", \"value\": \"\`${LABELS}\`\", \"inline\": true}"
fi

if [ "$IS_DRAFT" == "true" ]; then
  FIELDS="${FIELDS}, {\"name\": \"Status\", \"value\": \"📝 Draft\", \"inline\": true}"
fi

FIELDS="${FIELDS}]"

cat > /tmp/pr-notify.json << EOF
{
  "embeds": [{
    "title": "${EMOJI} ${TITLE}",
    "description": "${FULL_DESCRIPTION}",
    "color": ${COLOR},
    "fields": ${FIELDS},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "footer": {"text": "GitHub PR Activity"}
  }]
}
EOF

WEBHOOK_URL="${DISCORD_PR_WEBHOOK}"
curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d @/tmp/pr-notify.json
