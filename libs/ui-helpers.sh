#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # Handle both sourced and executed contexts
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 1  # Script is being sourced
  else
    exit 1    # Script is being executed directly
  fi
fi

# UI Layout Constants
readonly DEFAULT_BOX_WIDTH=55
readonly SECTION_BORDER_WIDTH=8    # "━━━ " (4) + " ━━━" (4)
readonly BOX_TOP_BORDER_WIDTH=5    # "╭─ " (3) + " " (1) + "╮" (1)
readonly BOX_SIDE_BORDER_WIDTH=4   # "│ " (2) + " │" (2)
readonly BOX_BOTTOM_BORDER_WIDTH=2 # "╰" (1) + "╯" (1)

# Brief: Display formatted progress messages with color and symbols
# Params: $1 - level (step/info/success/warning/error/validation), $@ - message text
# Uses: DEVBASE_COLORS, DEVBASE_SYMBOLS (globals)
# Returns: 0 always
show_progress() {
  local level="$1"
  shift
  local message="$*"

  case "$level" in
  # Main actions/phases
  step)
    printf "%b%s %b%b\n" "${DEVBASE_COLORS[BOLD]}" "${DEVBASE_SYMBOLS[ARROW]}" "$message" "${DEVBASE_COLORS[NC]}"
    ;;

  # Information/details
  info)
    printf "    %b\n" "$message"
    ;;

  # Success/completion
  success)
    printf "  %b%s%b %b\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_SYMBOLS[CHECK]}" "${DEVBASE_COLORS[NC]}" "$message"
    ;;

  # Warning
  warning)
    printf "  %b%s %s%b\n" "${DEVBASE_COLORS[YELLOW]}" "${DEVBASE_SYMBOLS[WARN]}" "$message" "${DEVBASE_COLORS[NC]}"
    ;;

  # Error (non-fatal by default - caller decides if fatal)
  error)
    printf "  %b%s%b %b\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_SYMBOLS[CROSS]}" "${DEVBASE_COLORS[NC]}" "$message" >&2
    ;;

  # Validation error (non-fatal, for user input)
  validation)
    printf "    %b%s%b %b\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_SYMBOLS[VALIDATION_ERROR]}" "${DEVBASE_COLORS[NC]}" "$message"
    ;;

  # Fallback
  *)
    printf "  %s\n" "$message"
    ;;
  esac
  return 0
}

# Brief: Repeat a character N times for box drawing
# Params: $1 - character to repeat, $2 - count
# Returns: Echoes repeated character string to stdout
repeat_char() {
  local char="$1"
  local count="$2"
  printf "${char}%.0s" $(seq 1 "$count")
}

# Brief: Print section header with horizontal line decoration
# Params: $1 - title text, $2 - color code (optional, default: BOLD_CYAN)
# Uses: DEFAULT_BOX_WIDTH, SECTION_BORDER_WIDTH, DEVBASE_COLORS (globals)
# Returns: 0 always
# Side-effects: Prints formatted section header to stdout
print_section() {
  local title="$1"
  local width="${DEFAULT_BOX_WIDTH}"
  local color="${2:-${DEVBASE_COLORS[BOLD_CYAN]}}"
  local title_len=${#title}
  local remaining=$((width - title_len - SECTION_BORDER_WIDTH))
  printf "%b━━━ %s %s━━━%b\n" "$color" "$title" "$(repeat_char '━' $remaining)" "${DEVBASE_COLORS[NC]}"
}

# Brief: Print top border of box with title
# Params: $1 - title text, $2 - width (optional), $3 - color code (optional)
# Uses: DEFAULT_BOX_WIDTH, BOX_TOP_BORDER_WIDTH, DEVBASE_COLORS (globals)
# Returns: 0 always
# Side-effects: Prints formatted box top to stdout
print_box_top() {
  local title="$1"
  local width="${2:-${DEFAULT_BOX_WIDTH}}"
  local color="${3:-${DEVBASE_COLORS[CYAN]}}"
  local title_len=${#title}
  local remaining=$((width - title_len - BOX_TOP_BORDER_WIDTH))
  printf "%b╭─ %s %s╮%b\n" "$color" "$title" "$(repeat_char '─' $remaining)" "${DEVBASE_COLORS[NC]}"
}

# Brief: Print single line of box content with borders
# Params: $1 - content text, $2 - width (optional), $3 - color code (optional)
# Uses: DEFAULT_BOX_WIDTH, BOX_SIDE_BORDER_WIDTH, DEVBASE_COLORS (globals)
# Returns: 0 always
# Side-effects: Prints formatted box line to stdout
print_box_line() {
  local content="$1"
  local width="${2:-${DEFAULT_BOX_WIDTH}}"
  local color="${3:-${DEVBASE_COLORS[CYAN]}}"
  local visible_len=${#content}
  local spaces=$((width - visible_len - BOX_SIDE_BORDER_WIDTH))
  printf "%b│ %s%-*s │%b\n" "$color" "$content" "$spaces" "" "${DEVBASE_COLORS[NC]}"
}

# Brief: Print bottom border of box
# Params: $1 - width (optional), $2 - color code (optional)
# Uses: DEFAULT_BOX_WIDTH, BOX_BOTTOM_BORDER_WIDTH, DEVBASE_COLORS (globals)
# Returns: 0 always
# Side-effects: Prints formatted box bottom to stdout
print_box_bottom() {
  local width="${1:-${DEFAULT_BOX_WIDTH}}"
  local color="${2:-${DEVBASE_COLORS[CYAN]}}"
  local line_count=$((width - BOX_BOTTOM_BORDER_WIDTH))
  printf "%b╰%s╯%b\n" "$color" "$(repeat_char '─' $line_count)" "${DEVBASE_COLORS[NC]}"
}

# Brief: Print formatted prompt with optional default value
# Params: $1 - prompt text, $2 - default value (optional), $3 - color code (optional)
# Uses: DEVBASE_COLORS (globals)
# Returns: 0 always
# Side-effects: Prints prompt to stdout without newline
print_prompt() {
  local prompt="$1"
  local default="$2"
  local color="${3:-${DEVBASE_COLORS[LIGHTYELLOW]}}"

  if [[ -n "$default" ]]; then
    printf "  %b%s (default: %s): %b" "$color" "$prompt" "$default" "${DEVBASE_COLORS[NC]}"
  else
    printf "  %b%s: %b" "$color" "$prompt" "${DEVBASE_COLORS[NC]}"
  fi
}

# Brief: Ask yes/no question and return user response
# Params: $1 - question text, $2 - default ("Y" or "N", default: "N")
# Uses: print_prompt, show_progress (from this file)
# Returns: 0 for yes, 1 for no
# Side-effects: Reads single character from stdin, prints to stdout
ask_yes_no() {
  local question="$1"
  local default="${2:-N}"
  local response

  while true; do
    print_prompt "$question" "$default"
    read -n 1 -r -s response
    printf "%s\n" "$response"

    if [[ -z "$response" ]]; then
      response="$default"
    fi

    if [[ "$response" =~ ^[YyNn]$ ]]; then
      if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
      else
        return 1
      fi
    else
      show_progress validation "Please enter Y or N"
    fi
  done
}

# Brief: Print error message with symbol (stderr)
# Params: $1 - message text
# Uses: DEVBASE_COLORS, DEVBASE_SYMBOLS (globals)
# Returns: 0 always
# Side-effects: Prints to stderr
error_msg() {
  printf "  %b%s%b %s\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_SYMBOLS[CROSS]}" "${DEVBASE_COLORS[NC]}" "$1" >&2
}

warn_msg() {
  printf "  %b%s%b %s\n" "${DEVBASE_COLORS[YELLOW]}" "${DEVBASE_SYMBOLS[WARN]}" "${DEVBASE_COLORS[NC]}" "$1" >&2
}

# Brief: Print success message with symbol
# Params: $1 - message text
# Uses: DEVBASE_COLORS, DEVBASE_SYMBOLS (globals)
# Returns: 0 always
# Side-effects: Prints to stdout
success_msg() {
  printf "  %b%s%b %s\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_SYMBOLS[CHECK]}" "${DEVBASE_COLORS[NC]}" "$1"
}

info_msg() {
  printf "  %b%s%b %s\n" "${DEVBASE_COLORS[CYAN]}" "${DEVBASE_SYMBOLS[INFO]}" "${DEVBASE_COLORS[NC]}" "$1"
}
